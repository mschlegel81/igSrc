UNIT imageContexts;
INTERFACE
USES sysutils,
     myParams,
     mypics,
     mySys,
     Dialogs,
     imageStashes,
     generationBasics,
     pixMaps,
     serializationUtil;

TYPE
  T_workflowType=(wft_generative,wft_manipulative,wft_fixated,wft_halfFix,wft_generativeWithSave,wft_manipulativeWithSave,wft_empty_or_unknown);
CONST
  C_workflowTypeString:array[T_workflowType] of string=('generative','manipulative','fix','half-fix','generative, save fixed','manipulative, save fixed','empty or unknown');
TYPE
  P_abstractWorkflow=^T_abstractWorkflow;

  T_imageManipulationCategory=(imc_generation,imc_imageAccess,imc_geometry,imc_colors,imc_combination,imc_statistic,imc_filter,imc_misc);
  P_imageOperation=^T_imageOperation;
  P_imageOperationMeta=^T_imageOperationMeta;
  T_imageOperationMeta=object
    private
      cat:T_imageManipulationCategory;
    protected
      name:string;
    public
      CONSTRUCTOR create(CONST name_:string; CONST cat_:T_imageManipulationCategory);
      PROPERTY category:T_imageManipulationCategory read cat;
      PROPERTY getName:string read name;
      DESTRUCTOR destroy; virtual;
      FUNCTION parse(CONST specification:ansistring):P_imageOperation; virtual; abstract;
      FUNCTION getSimpleParameterDescription:P_parameterDescription; virtual; abstract;
      FUNCTION getDefaultOperation:P_imageOperation; virtual; abstract;
      FUNCTION getDefaultParameterString:string; virtual;
      FUNCTION getExpectedOutputResolution(CONST context:P_abstractWorkflow; CONST inputResolution:T_imageDimensions; CONST parameters:T_parameterValue):T_imageDimensions; virtual;
  end;

  { T_imageOperation }

  T_imageOperation=object
    protected
      fMeta:P_imageOperationMeta;
      PROCEDURE assignMetaOnce(CONST newMeta:P_imageOperationMeta);
    public
      CONSTRUCTOR create(CONST meta:P_imageOperationMeta);
      PROPERTY meta:P_imageOperationMeta read fMeta write assignMetaOnce;
      PROCEDURE execute(CONST context:P_abstractWorkflow); virtual; abstract;
      FUNCTION getSimpleParameterValue:P_parameterValue; virtual;
      DESTRUCTOR destroy; virtual;
      FUNCTION readsStash:string; virtual;
      FUNCTION writesStash:string; virtual;
      FUNCTION readsFile:string; virtual;
      FUNCTION writesFile:string; virtual;
      FUNCTION dependsOnImageBefore:boolean; virtual; abstract;
      FUNCTION modifiesImage:boolean; virtual;
      FUNCTION toString(nameMode:T_parameterNameMode):string; virtual; abstract;
      FUNCTION alterParameter(CONST newParameterString:string):boolean; virtual; abstract;
      FUNCTION getExpectedOutputResolution(CONST context:P_abstractWorkflow; CONST inputResolution:T_imageDimensions):T_imageDimensions; virtual;
  end;

  F_errorFeedbackRoutine=PROCEDURE(CONST message:string) of object;
  T_taskState=(ts_pending,    //set on construction
               ts_evaluating, //set on dequeue
               ts_ready,      //set after evaluation
               ts_cancelled,
               ts_hardStopRequested,
               ts_softStopRequested);
  P_parallelTask=^T_parallelTask;
  T_parallelTask=object
    id:longint;
    containedIn:P_abstractWorkflow;
    nextTask   :P_parallelTask;
    state:T_taskState;
    CONSTRUCTOR create(CONST id_:longint);
    DESTRUCTOR destroy; virtual;
    PROCEDURE execute; virtual; abstract;
  end;

  T_abstractWorkflow=object(T_serializable)
    protected
      contextCS:TRTLCriticalSection;
      currentExecution:record
        currentStepIndex:longint;
        workflowState:T_taskState;
      end;
      PROCEDURE beforeAll; virtual; abstract;
      PROCEDURE headlessWorkflowExecution; virtual; abstract;
    private
      queue:record
        firstTask,
        lastTask:P_parallelTask;
        stepsTotal,stepsDone,
        queuedCount,
        workerCount:longint;
        queueStarted:double;
        lastQueueLog:double;
      end;
      PROCEDURE notifyWorkerStopped;
      PROCEDURE logParallelStepDone;
      PROCEDURE ensureWorkers;
      PROCEDURE executeQueueTasks;
    public
      previewQuality:boolean;
      messageQueue:P_structuredMessageQueue;
      stash:T_imageStash;
      image:T_rawImage;

      CONSTRUCTOR createContext(CONST messageQueue_:P_structuredMessageQueue);
      DESTRUCTOR destroy; virtual;
      //Parellelization:
      PROCEDURE clearQueue;
      PROCEDURE enqueueAll(CONST task:P_parallelTask);
      PROCEDURE enqueue   (CONST task:P_parallelTask);
      PROCEDURE waitForFinishOfParallelTasks;
      //General workflow control
      PROCEDURE ensureStop;
      PROCEDURE postStop;
      PROCEDURE stopBeforeEditing(CONST firstIndex,lastIndex:longint);
      FUNCTION  executing:boolean;
      FUNCTION  isDone:boolean;
      FUNCTION  cancellationRequested:boolean;
      PROCEDURE cancelWithError(CONST errorMessage:string);
      PROCEDURE clear;
      PROPERTY currentStepIndex:longint read currentExecution.currentStepIndex;
      PROCEDURE executeWorkflowInBackground(CONST preview: boolean);
      FUNCTION isValid: boolean; virtual; abstract;
      FUNCTION limitedDimensionsForResizeStep(CONST tgtDim:T_imageDimensions):T_imageDimensions; virtual; abstract;
      FUNCTION limitImageSize:boolean; virtual; abstract;
      FUNCTION isEditorWorkflow:boolean; virtual;
      FUNCTION stepCount:longint; virtual; abstract;
  end;

VAR maxImageManipulationThreads:longint=1;
    maxMessageLength:longint=100;
    queueLogInterval:double=10/(24*60*60); //=10 seconds
    allImageOperations:array of P_imageOperationMeta;
PROCEDURE registerOperation(CONST meta: P_imageOperationMeta);
FUNCTION parseOperation(CONST specification:string):P_imageOperation;
IMPLEMENTATION
USES myGenerics,myStringUtil;
TYPE T_opList=array of P_imageOperationMeta;

T_imagePreparationWorkerThread=class(T_basicThread)
  protected
    workflow:P_abstractWorkflow;
    executeMainWorkflow:boolean;
    PROCEDURE execute; override;
  public
    CONSTRUCTOR create(CONST workflow_:P_abstractWorkflow; CONST executeMain:boolean);
    DESTRUCTOR destroy; override;
end;
VAR globalWorkersRunning:longint=0;
    operationMap:specialize G_stringKeyMap<T_opList>;

FUNCTION extractName(CONST s:string):string;
  CONST splitters:array [0..1] of string=(':','[');
  VAR tmp:T_arrayOfString;
  begin
    tmp:=split(s,splitters);
    if length(tmp)=0 then exit('');
    result:=trim(tmp[0]);
    setLength(tmp,0);
  end;

PROCEDURE registerOperation(CONST meta: P_imageOperationMeta);
  VAR key:string;
      value:T_opList;
      {$ifdef debugMode}
      parsedDefault:P_imageOperation;
      {$endif}
  begin
    setLength(allImageOperations,length(allImageOperations)+1);
    allImageOperations[length(allImageOperations)-1]:=meta;
    key:=extractName(meta^.getName);
    if operationMap.containsKey(key,value) then begin
      setLength(value,length(value)+1);
      value[length(value)-1]:=meta;
    end else begin
      setLength(value,1);
      value[0]:=meta;
    end;
    operationMap.put(key,value);
    {$ifdef debugMode}
    //writeln(stdErr,'Registering opereration ',meta^.getName);
    //writeln(stdErr,'Default operation is ',meta^.getDefaultParameterString);
    if meta^.category<>imc_generation then begin
      parsedDefault:=meta^.parse(meta^.getDefaultParameterString);
      if parsedDefault=nil
      then raise Exception.create('CANNOT PARSE DEFAULT STRING! "'+meta^.getDefaultParameterString+'"')
      else dispose(parsedDefault,destroy);
    end;
    {$endif}
  end;

FUNCTION parseOperation(CONST specification:string):P_imageOperation;
  VAR key:string;
      value:T_opList;
      meta:P_imageOperationMeta;
  begin
    key:=extractName(specification);
    result:=nil;
    if operationMap.containsKey(key,value) then begin
      for meta in value do if (result=nil) then begin
        result:=meta^.parse(specification);
      end;
    end
  end;

PROCEDURE T_imagePreparationWorkerThread.execute;
  begin
    if executeMainWorkflow
    then workflow^.headlessWorkflowExecution
    else begin
      workflow^.executeQueueTasks;
      workflow^.notifyWorkerStopped;
    end;
  end;

CONSTRUCTOR T_imagePreparationWorkerThread.create(CONST workflow_: P_abstractWorkflow; CONST executeMain: boolean);
  begin
    workflow:=workflow_;
    interLockedIncrement(globalWorkersRunning);
    executeMainWorkflow:=executeMain;
    inherited create();
  end;

DESTRUCTOR T_imagePreparationWorkerThread.destroy;
begin
  inherited destroy;
  interlockedDecrement(globalWorkersRunning);
end;

DESTRUCTOR T_imageOperation.destroy; begin end;

PROCEDURE T_imageOperation.assignMetaOnce(CONST newMeta: P_imageOperationMeta);
  begin
    if fMeta=nil then fMeta:=newMeta else raise Exception.create('Reassigning meta is forbidden');
  end;
CONSTRUCTOR T_imageOperation.create(CONST meta: P_imageOperationMeta); begin fMeta:=meta; end;
FUNCTION T_imageOperation.getSimpleParameterValue: P_parameterValue; begin result:=nil; end;
FUNCTION T_imageOperation.readsStash: string; begin result:=''; end;
FUNCTION T_imageOperation.writesStash: string; begin result:=''; end;
FUNCTION T_imageOperation.readsFile: string; begin result:=''; end;
FUNCTION T_imageOperation.writesFile: string; begin result:=''; end;
FUNCTION T_imageOperation.modifiesImage: boolean; begin result:=true; end;

FUNCTION T_imageOperation.getExpectedOutputResolution(CONST context: P_abstractWorkflow; CONST inputResolution: T_imageDimensions): T_imageDimensions;
  begin
    result:=inputResolution;
  end;

CONSTRUCTOR T_imageOperationMeta.create(CONST name_: string;
  CONST cat_: T_imageManipulationCategory);
  begin
    name:=name_;
    cat :=cat_;
  end;

DESTRUCTOR T_imageOperationMeta.destroy;
  begin
  end;

FUNCTION T_imageOperationMeta.getDefaultParameterString: string;
  VAR temporaryOperation:P_imageOperation;
  begin
    temporaryOperation:=getDefaultOperation;
    result:=temporaryOperation^.toString(tsm_withNiceParameterName);
    dispose(temporaryOperation,destroy);
  end;

FUNCTION T_imageOperationMeta.getExpectedOutputResolution(CONST context:P_abstractWorkflow; CONST inputResolution:T_imageDimensions; CONST parameters:T_parameterValue):T_imageDimensions;
  begin
    result:=inputResolution;
  end;

CONSTRUCTOR T_parallelTask.create(CONST id_:longint);
  begin
    id:=id_;
    containedIn:=nil;
    nextTask   :=nil;
    state      :=ts_pending;
  end;

DESTRUCTOR T_parallelTask.destroy;
  begin
  end;

PROCEDURE T_abstractWorkflow.notifyWorkerStopped;
  begin
    enterCriticalSection(contextCS);
    try
      dec(queue.workerCount);
    finally
      leaveCriticalSection(contextCS);
    end;
  end;

PROCEDURE T_abstractWorkflow.logParallelStepDone;
  begin
    enterCriticalSection(contextCS);
    try
      inc(queue.stepsDone);
      if now>queue.lastQueueLog+queueLogInterval then begin
        // (endTime-queue.queueStarted)/(now-queue.queueStarted) = queue.stepsTotal/queue.stepsDone
        // (endTime-queue.queueStarted)                          = queue.stepsTotal/queue.stepsDone*(now-queue.queueStarted)
        //  endTime                                              = queue.stepsTotal/queue.stepsDone*(now-queue.queueStarted)+queue.queueStarted
        messageQueue^.Post(intToStr(round(100.0*queue.stepsDone/queue.stepsTotal))+'% ('+intToStr(queue.stepsDone)+'/'+intToStr(queue.stepsTotal)+') rem: '
          +myTimeToStr(queue.stepsTotal/queue.stepsDone*(now-queue.queueStarted)+queue.queueStarted-now),false,currentExecution.currentStepIndex,stepCount);
        queue.lastQueueLog:=now;
      end;
    finally
      leaveCriticalSection(contextCS);
    end;
  end;

PROCEDURE T_abstractWorkflow.ensureWorkers;
  begin
    enterCriticalSection(contextCS);
    try
      while (globalWorkersRunning<maxImageManipulationThreads) and (getGlobalThreads<GLOBAL_THREAD_LIMIT) do begin
        inc(queue.workerCount);
        T_imagePreparationWorkerThread.create(@self,false);
      end;
    finally
      leaveCriticalSection(contextCS);
    end;
  end;

PROCEDURE T_abstractWorkflow.executeQueueTasks;
  FUNCTION dequeue: P_parallelTask;
    begin
      enterCriticalSection(contextCS);
      with queue do try
        result:=firstTask;
        if firstTask<>nil then begin
          firstTask:=firstTask^.nextTask;
          dec(queuedCount);
        end;
      finally
        leaveCriticalSection(contextCS);
      end;
    end;

  VAR task:P_parallelTask;
  begin
    task:=dequeue;
    while (task<>nil) do begin
      task^.state:=ts_evaluating;
      if not(currentExecution.workflowState in [ts_cancelled,ts_hardStopRequested,ts_softStopRequested])
      then begin
        task^.execute;
        logParallelStepDone;
      end;
      dispose(task,destroy);
      task:=dequeue;
    end;
  end;

CONSTRUCTOR T_abstractWorkflow.createContext(
  CONST messageQueue_: P_structuredMessageQueue);
  begin
    initCriticalSection(contextCS);
    messageQueue:=messageQueue_;
    with queue do begin
      firstTask     :=nil;
      lastTask      :=nil;
      queuedCount   :=0;
      workerCount   :=0;
      stepsDone     :=0;
      stepsTotal    :=0;
    end;
    stash         .create(@cancelWithError);
    image         .create(1,1);
    with currentExecution do begin
      currentStepIndex:=-1;
      workflowState:=ts_cancelled;
    end;
  end;

DESTRUCTOR T_abstractWorkflow.destroy;
  begin
    {$ifdef debugMode}
    writeln(stdErr,'DEBUG T_imageGenerationContext.destroy (enter)');
    {$endif}
    ensureStop;
    enterCriticalSection(contextCS);
    try
      stash.destroy;
      image.destroy;
    finally
      leaveCriticalSection(contextCS);
    end;
    doneCriticalSection(contextCS);
    {$ifdef debugMode}
    writeln(stdErr,'DEBUG T_imageGenerationContext.destroy (exit)');
    {$endif}
  end;

PROCEDURE T_abstractWorkflow.clearQueue;
  begin
    enterCriticalSection(contextCS);
    with queue do while workerCount>0 do begin
      leaveCriticalSection(contextCS);
      sleep(1);
      enterCriticalSection(contextCS);
    end;
    with queue do try
      firstTask     :=nil;
      lastTask      :=nil;
      queuedCount   :=0;
      workerCount   :=0;
      stepsDone     :=0;
      stepsTotal    :=0;
      lastQueueLog  :=now;
      queueStarted  :=now;
    finally
      leaveCriticalSection(contextCS);
    end;
  end;

PROCEDURE T_abstractWorkflow.enqueueAll(CONST task: P_parallelTask);
  begin
    enterCriticalSection(contextCS);
    with queue do try
      if firstTask=nil
      then firstTask         :=task
      else lastTask^.nextTask:=task;
      while lastTask^.nextTask<>nil do begin
        lastTask^.nextTask^.containedIn:=@self;
        lastTask:=lastTask^.nextTask;
        inc(queuedCount);
        inc(stepsTotal);
      end;
      ensureWorkers;
    finally
      leaveCriticalSection(contextCS);
    end;
  end;

PROCEDURE T_abstractWorkflow.enqueue(CONST task: P_parallelTask);
  begin
    enterCriticalSection(contextCS);
    with queue do try
      if firstTask=nil
      then firstTask         :=task
      else lastTask^.nextTask:=task;
      task^.containedIn:=@self;
      lastTask:=task;
      inc(queuedCount);
      inc(stepsTotal);
      ensureWorkers;
    finally
      leaveCriticalSection(contextCS);
    end;
  end;

PROCEDURE T_abstractWorkflow.waitForFinishOfParallelTasks;
  begin
    with queue do if (workerCount>=0) then begin
      enterCriticalSection(contextCS);
      //The current thread will execute one worker
      leaveCriticalSection(contextCS);

      executeQueueTasks;

      enterCriticalSection(contextCS);
      while workerCount<>0 do begin
        leaveCriticalSection(contextCS);
        {$ifdef debugMode}
        writeln('I am still waiting for workers to finish (',workerCount,') ',FormatDateTime('hh:nn:ss.zzz',now));
        {$endif}
        sleep(random(10));
        enterCriticalSection(contextCS);
      end;
      leaveCriticalSection(contextCS);
    end;
  end;

PROCEDURE T_abstractWorkflow.ensureStop;
  begin
    enterCriticalSection(contextCS);
    if currentExecution.workflowState=ts_evaluating then begin
      currentExecution.workflowState:=ts_hardStopRequested;
      messageQueue^.Post('Stopping',false,currentExecution.currentStepIndex,stepCount);
    end;
    while not(currentExecution.workflowState in [ts_cancelled,ts_ready]) do begin
      leaveCriticalSection(contextCS);
      sleep(1);
      enterCriticalSection(contextCS);
    end;
    leaveCriticalSection(contextCS);
  end;

PROCEDURE T_abstractWorkflow.stopBeforeEditing(CONST firstIndex,lastIndex:longint);
  VAR hard:boolean;
  begin
    enterCriticalSection(contextCS);
    hard:=(currentExecution.currentStepIndex>=firstIndex) and (currentExecution.currentStepIndex<=lastIndex);
    if currentExecution.workflowState=ts_evaluating then begin
      if hard
      then currentExecution.workflowState:=ts_hardStopRequested
      else currentExecution.workflowState:=ts_softStopRequested;
      messageQueue^.Post('Stopping',false,currentExecution.currentStepIndex,stepCount);
    end;
    while not(currentExecution.workflowState in [ts_cancelled,ts_ready]) and hard do begin
      leaveCriticalSection(contextCS);
      sleep(1);
      enterCriticalSection(contextCS);
    end;
    leaveCriticalSection(contextCS);
  end;

PROCEDURE T_abstractWorkflow.postStop;
  begin
    enterCriticalSection(contextCS);
    if currentExecution.workflowState=ts_evaluating then begin
      currentExecution.workflowState:=ts_softStopRequested;
      messageQueue^.Post('Stopping',false,currentExecution.currentStepIndex,stepCount);
    end;
    leaveCriticalSection(contextCS);
  end;

FUNCTION T_abstractWorkflow.executing: boolean;
  begin
    enterCriticalSection(contextCS);
    result:=currentExecution.workflowState in [ts_pending,ts_evaluating,ts_hardStopRequested,ts_softStopRequested];
    leaveCriticalSection(contextCS);
  end;

FUNCTION T_abstractWorkflow.isDone: boolean;
  begin
    enterCriticalSection(contextCS);
    result:=currentExecution.workflowState=ts_ready;
    leaveCriticalSection(contextCS);
  end;

FUNCTION T_abstractWorkflow.cancellationRequested: boolean;
  begin
    enterCriticalSection(contextCS);
    result:=currentExecution.workflowState=ts_hardStopRequested;
    leaveCriticalSection(contextCS);
  end;

PROCEDURE T_abstractWorkflow.cancelWithError(CONST errorMessage: string);
  begin
    enterCriticalSection(contextCS);
    if currentExecution.workflowState=ts_evaluating then begin
      currentExecution.workflowState:=ts_hardStopRequested;
      messageQueue^.Post(errorMessage,true,currentExecution.currentStepIndex,stepCount);
    end;
    leaveCriticalSection(contextCS);
  end;

PROCEDURE T_abstractWorkflow.clear;
  begin
    ensureStop;
    enterCriticalSection(contextCS);
    try
      stash.clear;
    finally
      leaveCriticalSection(contextCS);
    end;
  end;

PROCEDURE T_abstractWorkflow.executeWorkflowInBackground(CONST preview: boolean);
  begin
    if not(isValid) then exit;
    ensureStop;
    queue.workerCount:=0;
    currentExecution.workflowState:=ts_evaluating;
    previewQuality:=preview;
    beforeAll;
    T_imagePreparationWorkerThread.create(@self,true);
  end;

FUNCTION T_abstractWorkflow.isEditorWorkflow: boolean;
  begin
    result:=false;
  end;

PROCEDURE finalizeAlgorithms;
  VAR i:longint;
  begin
    for i:=0 to length(allImageOperations)-1 do dispose(allImageOperations[i],destroy);
    setLength(allImageOperations,0);
  end;

PROCEDURE clearArray(VAR a:T_opList);
  begin
    setLength(a,0);
  end;

INITIALIZATION
  maxImageManipulationThreads:=getNumberOfCPUs;
  operationMap.create(@clearArray);
FINALIZATION
  finalizeAlgorithms;
  operationMap.destroy;
end.

