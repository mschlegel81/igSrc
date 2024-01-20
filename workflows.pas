UNIT workflows;
INTERFACE
USES myGenerics,
     pixMaps,
     myParams,mypics,sysutils,imageGeneration,mySys,FileUtil,Dialogs,
     generationBasics,
     imageContexts,workflowSteps,serializationUtil;

TYPE
  P_simpleWorkflow=^T_simpleWorkflow;
  T_simpleWorkflow=object(T_abstractWorkflow)
    protected
      startedAt:double;
      steps: array of P_workflowStep;
      PROCEDURE headlessWorkflowExecution; virtual;
      PROCEDURE afterStep(CONST stepIndex:longint; CONST elapsed:double); virtual;
      PROCEDURE beforeAll; virtual;
      PROCEDURE afterAll ;
      PROCEDURE configChanged; virtual;
      PROCEDURE checkStepIO;
    private
      FUNCTION getStep(index:longint):P_workflowStep;
    public
      config:T_imageWorkflowConfiguration;
      CONSTRUCTOR createSimpleWorkflow(CONST messageQueue_:P_structuredMessageQueue);
      DESTRUCTOR destroy; virtual;
      PROCEDURE clear;
      PROPERTY step[index:longint]: P_workflowStep read getStep;
      FUNCTION stepCount:longint; virtual;
      FUNCTION parseWorkflow(data:T_arrayOfString; CONST tolerantParsing:boolean):boolean;
      FUNCTION workflowText:T_arrayOfString;
      FUNCTION readWorkflowOnlyFromFile(CONST fileName:string; CONST tolerantParsing:boolean):boolean;
      PROCEDURE saveWorkflowOnlyToFile(CONST fileName:string);
      FUNCTION todoLines(CONST savingToFile:string; CONST savingWithSizeLimit:longint):T_arrayOfString;
      PROCEDURE saveAsTodo(CONST savingToFile:string; CONST savingWithSizeLimit:longint);
      PROCEDURE appendSaveStep(CONST savingToFile:string; CONST savingWithSizeLimit:longint);
      FUNCTION executeAsTodo:boolean;

      FUNCTION workflowType:T_workflowType;
      FUNCTION proposedImageFileName(CONST resString:ansistring):string;
      FUNCTION addStep(CONST specification:string; CONST atIndex:longint):boolean;
      PROCEDURE addStep(CONST operation:P_imageOperation; CONST atIndex:longint);
      PROCEDURE addStep(CONST newStep:P_workflowStep; CONST atIndex:longint);

      FUNCTION isValid: boolean; virtual;
      FUNCTION limitedDimensionsForResizeStep(CONST tgtDim:T_imageDimensions):T_imageDimensions; virtual;
      FUNCTION limitImageSize:boolean; virtual;
  end;

  P_editorWorkflow=^T_editorWorkflow;

  { T_editorWorkflow }

  T_editorWorkflow=object(T_simpleWorkflow)
    protected
      PROCEDURE beforeAll; virtual;
      PROCEDURE afterStep(CONST stepIndex:longint; CONST elapsed:double); virtual;
      PROCEDURE configChanged; virtual;
    public
      CONSTRUCTOR createEditorWorkflow(CONST messageQueue_:P_structuredMessageQueue);
      PROCEDURE stepChanged(CONST index:longint);
      PROCEDURE swapStepDown(CONST firstIndex,lastIndex:longint);
      PROCEDURE removeStep(CONST firstIndex,lastIndex:longint);
      FUNCTION isEditorWorkflow: boolean; virtual;

      FUNCTION getSerialVersion:dword; virtual;
      FUNCTION loadFromStream(VAR stream:T_bufferedInputStreamWrapper):boolean; virtual;
      PROCEDURE saveToStream(VAR stream:T_bufferedOutputStreamWrapper); virtual;
  end;

  P_generateImageWorkflow=^T_generateImageWorkflow;
  T_generateImageWorkflow=object(T_abstractWorkflow)
    private
      relatedEditor:P_editorWorkflow;
      editingStep:longint;
      addingNewStep:boolean;
      current:P_algorithmMeta;
      PROCEDURE setAlgorithmIndex(CONST index:longint);
      FUNCTION getAlgorithmIndex:longint;
    protected
      PROCEDURE beforeAll; virtual;
      PROCEDURE headlessWorkflowExecution; virtual;
    public
      CONSTRUCTOR createOneStepWorkflow(CONST messageQueue_:P_structuredMessageQueue; CONST relatedEditor_:P_editorWorkflow);
      PROPERTY algorithmIndex:longint read getAlgorithmIndex write setAlgorithmIndex;
      PROPERTY algorithm:P_algorithmMeta read current;
      FUNCTION startEditing(CONST stepIndex:longint):boolean;
      PROCEDURE startEditingForNewStep(CONST toBeInsertedAtIndex:longint);
      PROCEDURE confirmEditing;
      FUNCTION isValid: boolean; virtual;
      FUNCTION limitedDimensionsForResizeStep(CONST tgtDim:T_imageDimensions):T_imageDimensions; virtual;
      FUNCTION limitImageSize:boolean; virtual;
      FUNCTION stepCount:longint; virtual;
      PROPERTY getRelatedEditor:P_editorWorkflow read relatedEditor;
  end;

  T_standaloneWorkflow=object(T_simpleWorkflow)
    CONSTRUCTOR create;
    DESTRUCTOR destroy; virtual;
  end;

IMPLEMENTATION
//These are binding uses
//Initialization of those units registers image operations
USES imageManipulation,
     im_stashing,
     im_geometry,
     im_colors,
     im_statisticOperations,
     im_filter,
     im_misc,
     ig_gradient,
     ig_perlin,
     ig_simples,
     ig_fractals,
     ig_epicycles,
     ig_ifs,
     ig_ifs2,
     ig_ifsMoebius,
     ig_bifurcation,
     ig_funcTrees,
     ig_expoClouds,
     ig_factorTables,
     im_triangleSplit,
     ig_circlespirals,
     ig_tesselation,
     ig_buddhaBrot,
     im_hq3x,
     myStringUtil,
     LazFileUtils;

CONSTRUCTOR T_standaloneWorkflow.create;
  VAR ownedMessageQueue:P_structuredMessageQueue;
  begin
    new(ownedMessageQueue,create);
    inherited createSimpleWorkflow(ownedMessageQueue);
  end;

DESTRUCTOR T_standaloneWorkflow.destroy;
  VAR ownedMessageQueue:P_structuredMessageQueue;
  begin
    ownedMessageQueue:=messageQueue;
    inherited destroy;
    dispose(ownedMessageQueue,destroy);
  end;

PROCEDURE T_generateImageWorkflow.beforeAll;
  begin
    enterCriticalSection(contextCS);
    enterCriticalSection(relatedEditor^.contextCS);
    try
      messageQueue^.postSeparator;
      messageQueue^.Post('Starting preview calculation',false,-1,0);
      image.resize(relatedEditor^.config.initialResolution,res_dataResize);
      if (editingStep>0) and (editingStep-1<relatedEditor^.stepCount) and (relatedEditor^.step[editingStep-1]^.outputImage<>nil) then begin
        image.copyFromPixMap(relatedEditor^.step[editingStep-1]^.outputImage^);
        relatedEditor^.config.limitImageSize(image);
      end else image.drawCheckerboard;
    finally
      leaveCriticalSection(contextCS);
      leaveCriticalSection(relatedEditor^.contextCS);
    end;
  end;

PROCEDURE T_generateImageWorkflow.headlessWorkflowExecution;
  VAR stepStarted:double;
  begin
    stepStarted:=now;
    {$ifdef debugMode}
    writeln(stdErr,'DEBUG T_generateImageWorkflow.headlessWorkflowExecution start');
    {$endif}
    current^.prototype^.execute(@self);
    {$ifdef debugMode}
    writeln(stdErr,'DEBUG T_generateImageWorkflow.headlessWorkflowExecution finalizing');
    {$endif}
    enterCriticalSection(contextCS);
    try
      if currentExecution.workflowState=ts_evaluating
      then begin
        messageQueue^.Post('Done '+myTimeToStr(now-stepStarted),false,-1,0);
        currentExecution.workflowState:=ts_ready;
      end else begin
        messageQueue^.Post('Cancelled '+myTimeToStr(now-stepStarted),false,-1,0);
        currentExecution.workflowState:=ts_cancelled;
      end;
    finally
      leaveCriticalSection(contextCS);
      {$ifdef debugMode}
      writeln(stdErr,'DEBUG T_generateImageWorkflow.headlessWorkflowExecution done');
      {$endif}
    end;
  end;

CONSTRUCTOR T_generateImageWorkflow.createOneStepWorkflow(
  CONST messageQueue_: P_structuredMessageQueue;
  CONST relatedEditor_: P_editorWorkflow);
  begin
    inherited createContext(messageQueue_);
    relatedEditor:=relatedEditor_;
    current:=imageGenerationAlgorithms[0];
  end;

FUNCTION T_generateImageWorkflow.startEditing(CONST stepIndex: longint): boolean;
  begin
    if not(relatedEditor^.step[stepIndex]^.isValid) or
       (relatedEditor^.step[stepIndex]^.operation=nil) or
       (relatedEditor^.step[stepIndex]^.operation^.meta^.category<>imc_generation) then exit(false);
    current:=P_algorithmMeta(relatedEditor^.step[stepIndex]^.operation^.meta);
    if not(current^.prototype^.canParseParametersFromString(relatedEditor^.step[stepIndex]^.specification,true)) then exit(false);
    addingNewStep:=false;
    editingStep:=stepIndex;
    result:=true;
  end;

PROCEDURE T_generateImageWorkflow.startEditingForNewStep(CONST toBeInsertedAtIndex:longint);
  begin
    current:=imageGenerationAlgorithms[0];
    addingNewStep:=true;
    editingStep:=toBeInsertedAtIndex;
  end;

PROCEDURE T_generateImageWorkflow.confirmEditing;
  begin
    if not(isValid) then exit;
    relatedEditor^.ensureStop;
    if addingNewStep then begin
      {$ifdef debugMode}writeln(stdErr,'DEBUG T_generateImageWorkflow.confirmEditing: adding a new step');{$endif}
      relatedEditor^.addStep(current^.prototype^.toString(tsm_forSerialization),editingStep);
    end else begin
      {$ifdef debugMode}writeln(stdErr,'DEBUG T_generateImageWorkflow.confirmEditing: updating step #',editingStep);{$endif}
      relatedEditor^.step[editingStep]^.specification:=current^.prototype^.toString(tsm_forSerialization);
      relatedEditor^.stepChanged(editingStep);
    end;
  end;

PROCEDURE T_generateImageWorkflow.setAlgorithmIndex(CONST index: longint);
  begin
    if (index>=0) and (index<length(imageGenerationAlgorithms)) then
    current:=imageGenerationAlgorithms[index];
  end;

FUNCTION T_generateImageWorkflow.getAlgorithmIndex: longint;
  begin
    result:=current^.index;
  end;

FUNCTION T_generateImageWorkflow.isValid: boolean;
  begin
    result:=true;
  end;

FUNCTION T_generateImageWorkflow.limitedDimensionsForResizeStep(CONST tgtDim: T_imageDimensions): T_imageDimensions;
  begin
    result:=relatedEditor^.config.limitedDimensionsForResizeStep(tgtDim);
  end;

FUNCTION T_generateImageWorkflow.limitImageSize: boolean;
  begin
    result:=relatedEditor^.config.limitImageSize(image);
  end;

FUNCTION T_generateImageWorkflow.stepCount:longint;
  begin result:=1; end;

PROCEDURE T_simpleWorkflow.headlessWorkflowExecution;
  VAR stepStarted:double;
  begin
    enterCriticalSection(contextCS);
    while (currentExecution.workflowState=ts_evaluating) and (currentExecution.currentStepIndex<length(steps)) do begin
      leaveCriticalSection(contextCS);
      stepStarted:=now;
      steps[currentExecution.currentStepIndex]^.execute(@self);
      enterCriticalSection(contextCS);
      afterStep(currentExecution.currentStepIndex,now-stepStarted);
      inc(currentExecution.currentStepIndex);
    end;
    afterAll;
    leaveCriticalSection(contextCS);
  end;

CONST reportStepTimeIfLargerThan={$ifdef debugMode}0.1/(24*60*60){$else}5/(24*60*60){$endif};
PROCEDURE T_simpleWorkflow.afterStep(CONST stepIndex: longint;
  CONST elapsed: double);
  VAR accessedStash:string='';
      thereIsALaterAccess:boolean=false;
      i:longint;
  begin
    if elapsed>reportStepTimeIfLargerThan then messageQueue^.Post('Finished step after '+myTimeToStr(elapsed),false,currentStepIndex,stepCount);
    begin
      accessedStash                         :=steps[stepIndex]^.operation^.readsStash;
      if accessedStash='' then accessedStash:=steps[stepIndex]^.operation^.writesStash;
      if accessedStash<>'' then begin
        //This step just accessed a stash
        //The stash can be dropped if there is no later reading access
        for i:=stepIndex+1 to length(steps)-1 do thereIsALaterAccess:=thereIsALaterAccess or (steps[i]^.operation^.readsStash=accessedStash);
        if not(thereIsALaterAccess) then stash.clearSingleStash(accessedStash);
      end;
    end;
  end;

PROCEDURE T_editorWorkflow.afterStep(CONST stepIndex: longint;
  CONST elapsed: double);
  begin
    if elapsed>reportStepTimeIfLargerThan then messageQueue^.Post('Finished step after '+myTimeToStr(elapsed),false,currentStepIndex,stepCount);
    step[stepIndex]^.saveOutputImage(image);
  end;

PROCEDURE T_simpleWorkflow.afterAll;
  begin
    waitForFinishOfParallelTasks;
    enterCriticalSection(contextCS);
    try
      stash.clear;
      if currentExecution.workflowState in [ts_pending,ts_evaluating] then currentExecution.workflowState:=ts_ready;
      if currentExecution.workflowState in [ts_stopRequested        ] then currentExecution.workflowState:=ts_cancelled;
      case currentExecution.workflowState of
        ts_ready: messageQueue^.Post('Workflow done '+myTimeToStr(now-startedAt),false,-1,0);
        ts_cancelled: messageQueue^.Post('Workflow cancelled '+myTimeToStr(now-startedAt),false,currentExecution.currentStepIndex,stepCount);
      end;
    finally
      leaveCriticalSection(contextCS);
    end;
  end;

FUNCTION T_simpleWorkflow.getStep(index: longint): P_workflowStep;
  begin
    if (index>=0) and (index<length(steps))
    then result:=steps[index]
    else result:=nil;
  end;

CONSTRUCTOR T_simpleWorkflow.createSimpleWorkflow(
  CONST messageQueue_: P_structuredMessageQueue);
  begin
    inherited createContext(messageQueue_);
    config.create(@configChanged);
    setLength(steps,0);
  end;

DESTRUCTOR T_simpleWorkflow.destroy;
  begin
    {$ifdef debugMode}
    writeln(stdErr,'DEBUG T_simpleWorkflow.destroy (enter)');
    {$endif}
    ensureStop;
    clear;
    config.destroy;
    setLength(steps,0);
    {$ifdef debugMode}
    writeln(stdErr,'DEBUG T_simpleWorkflow.destroy (call inherited)');
    {$endif}
    inherited destroy;
    {$ifdef debugMode}
    writeln(stdErr,'DEBUG T_simpleWorkflow.destroy (exit)');
    {$endif}
  end;

FUNCTION T_simpleWorkflow.stepCount: longint;
  begin
    result:=length(steps);
  end;

PROCEDURE T_simpleWorkflow.clear;
  VAR i:longint;
  begin
    ensureStop;
    enterCriticalSection(contextCS);
    try
      inherited clear;
      for i:=0 to length(steps)-1 do dispose(steps[i],destroy);
      setLength(steps,0);
    finally
      leaveCriticalSection(contextCS);
    end;
  end;

PROCEDURE T_simpleWorkflow.beforeAll;
  begin
    enterCriticalSection(contextCS);
    try
      startedAt:=now;
      currentExecution.workflowState:=ts_evaluating;
      currentExecution.currentStepIndex:=0;
      config.prepareImageForWorkflow(image);
      messageQueue^.Post('Starting workflow',false,-1,0)
    finally
      leaveCriticalSection(contextCS);
    end;
  end;

PROCEDURE T_editorWorkflow.beforeAll;
  VAR i:longint;
  begin
    enterCriticalSection(contextCS);
    try
      startedAt:=now;
      currentExecution.workflowState:=ts_evaluating;
      currentExecution.currentStepIndex:=0;
      if previewQuality<>config.intermediateResultsPreviewQuality
      then begin
        for i:=0 to length(steps)-1 do steps[i]^.clearOutputImage;
        stash.clear;
        config.intermediateResultsPreviewQuality:=previewQuality;
      end;
      with currentExecution do while (currentStepIndex<length(steps)) and (steps[currentStepIndex]^.outputImage<>nil) do inc(currentStepIndex);
      if currentExecution.currentStepIndex>0
      then image.copyFromPixMap(steps[currentExecution.currentStepIndex-1]^.outputImage^)
      else config.prepareImageForWorkflow(image);
      messageQueue^.postSeparator;
      if currentExecution.currentStepIndex=0
      then messageQueue^.Post('Starting workflow',false,-1,0)
      else messageQueue^.Post('Resuming workflow',false,currentExecution.currentStepIndex,stepCount);

      //clear stash and restore it from output images:
      stash.clear;
      for i:=0 to currentExecution.currentStepIndex-1 do if (steps[i]^.isValid) and (steps[i]^.outputImage<>nil) and (steps[i]^.operation^.writesStash<>'') then begin
        {$ifdef debugMode}messageQueue^.Post('Restoring stash "'+steps[i]^.operation^.writesStash+'" from output',false,i,stepCount); {$endif}
        stash.stashImage(steps[i]^.operation^.writesStash,
                         steps[i]^.outputImage^);
      end;

    finally
      leaveCriticalSection(contextCS);
    end;
  end;

FUNCTION T_simpleWorkflow.parseWorkflow(data: T_arrayOfString; CONST tolerantParsing:boolean): boolean;
  VAR newSteps:array of P_workflowStep=();
      i:longint;
      stepIndex:longint=0;
  begin
    setLength(newSteps,length(data));
    for i:=0 to length(data)-1 do data[i]:=trim(data[i]);
    dropValues(data,'');
    for i:=0 to length(data)-1 do begin
      new(newSteps[stepIndex],create(data[i]));
      if not(newSteps[stepIndex]^.isValid) then begin
        messageQueue^.Post('Invalid step: '+data[i],true,i,length(data));
        dispose(newSteps[stepIndex],destroy);
      end else inc(stepIndex);
    end;
    setLength(newSteps,stepIndex);
    //if parsing is not tolerant, then every input line must relate to one step
    result:=(stepIndex>0) and (tolerantParsing or (stepIndex=length(data)));
    if result then begin
      clear;
      enterCriticalSection(contextCS);
      try
        setLength(steps,length(newSteps));
        for i:=0 to length(steps)-1 do steps[i]:=newSteps[i];
        setLength(newSteps,0);
      finally
        leaveCriticalSection(contextCS);
      end;
    end else begin
      for i:=0 to length(newSteps)-1 do dispose(newSteps[i],destroy);
    end;
  end;

FUNCTION T_simpleWorkflow.workflowText: T_arrayOfString;
  VAR i:longint;
  begin
    enterCriticalSection(contextCS);
    try
      initialize(result);
      setLength(result,length(steps));
      for i:=0 to length(steps)-1 do result[i]:=steps[i]^.specification;
    finally
      leaveCriticalSection(contextCS);
    end;
  end;

FUNCTION T_simpleWorkflow.readWorkflowOnlyFromFile(CONST fileName: string; CONST tolerantParsing:boolean): boolean;
  begin
    messageQueue^.Post('Trying to parse workflow from file: '+fileName,false,-1,0);
    if not(fileExists(fileName)) then begin
      messageQueue^.Post('File "'+fileName+'" does not exist',true,-1,0);
      result:=false;
    end else begin
      result:=parseWorkflow(readFile(fileName),tolerantParsing);
      result:=result and (length(steps)>0);
      if result then begin
        config.workflowFilename:=fileName;
        messageQueue^.Post(fileName+' loaded',false,-1,0);
      end;
    end;
  end;

PROCEDURE T_simpleWorkflow.saveWorkflowOnlyToFile(CONST fileName: string);
  begin
    messageQueue^.Post('Writing workflow to file: '+fileName,false,-1,0);
    writeFile(fileName,workflowText);
    config.workflowFilename:=fileName;
  end;

FUNCTION T_simpleWorkflow.todoLines(CONST savingToFile:string; CONST savingWithSizeLimit:longint):T_arrayOfString;
  VAR saveStep:P_simpleImageOperation;
      myType:T_workflowType;
  begin
    myType:=workflowType;
    //Fixate initial state if not fixed yet:
    if myType in [wft_fixated,wft_halfFix]
    then result:=C_EMPTY_STRING_ARRAY
    else result:=config.getFirstTodoStep;

    //Append workflow
    append(result,workflowText);

    //Append save step (if not ending with a save step)
    if not(myType in [wft_fixated,wft_generativeWithSave,wft_manipulativeWithSave]) then begin
      saveStep:=getSaveStatement(savingToFile,savingWithSizeLimit);
      append(result,saveStep^.toString(tsm_withNiceParameterName));
      dispose(saveStep,destroy);
    end;
  end;

PROCEDURE T_simpleWorkflow.saveAsTodo(CONST savingToFile: string; CONST savingWithSizeLimit: longint);
  VAR todoBase,
      todoName:string;
      temporaryWorkflow:T_arrayOfString;
      counter:longint=0;
  begin
    temporaryWorkflow:=todoLines(savingToFile,savingWithSizeLimit);

    //Find appropriate todo-name and save
    todoBase:=ExtractFileNameWithoutExt(savingToFile);
    todoName:=todoBase+lowercase(C_todoExtension);
    while fileExists(todoName) do begin
      inc(counter);
      todoName:=todoBase+'_'+intToStr(counter)+lowercase(C_todoExtension);
    end;
    messageQueue^.Post('Writing todo to file: '+todoName,false,-1,0);
    writeFile(todoName,temporaryWorkflow);
  end;

PROCEDURE T_simpleWorkflow.appendSaveStep(CONST savingToFile: string;
  CONST savingWithSizeLimit: longint);
  VAR stepsBefore,k:longint;
      errorOcurred:boolean=false;
  begin
    enterCriticalSection(contextCS);
    stepsBefore:=length(steps);
    try
      k:=length(steps);
      setLength(steps,k+1);
      new(steps[k],create(getSaveStatement(savingToFile,savingWithSizeLimit)));
    except
      errorOcurred:=true;
      setLength(steps,stepsBefore);
    end;
    leaveCriticalSection(contextCS);
    if errorOcurred then raise Exception.create('The automatically generated save step is invalid');
  end;

FUNCTION T_simpleWorkflow.executeAsTodo: boolean;
  VAR i:longint;
      todoDir:string;
  begin
    if stepCount<1 then exit(false);
    todoDir:=ExtractFileDir(config.workflowFilename);
    for i:=0 to stepCount-1 do
    if (step[i]^.operation^.readsFile<>'') or (step[i]^.operation^.writesFile<>'') then begin
                         step[i]^.operation^.getSimpleParameterValue^.fileName:=
      ExpandFileNameUTF8(step[i]^.operation^.getSimpleParameterValue^.fileName,todoDir);
      step[i]^.refreshSpecString;
    end;
    if not(isValid) then exit(false);
    if step[stepCount-1]^.operation^.writesFile='' then begin
      messageQueue^.Post('Invalid todo workflow. The last operation must be a save statement.',true,stepCount-1,stepCount);
      exit(false);
    end;
    addStep(deleteOp.getOperationToDeleteFile(config.workflowFilename),maxLongint);
    executeWorkflowInBackground(false);
    result:=true;
  end;

PROCEDURE T_simpleWorkflow.checkStepIO;
  VAR stashesReady:T_arrayOfString;
      i:longint;
  begin
    setLength(stashesReady,0);
    if (length(steps)>0) and (steps[0]^.operation^.writesStash<>'') and (steps[0]^.outputImage<>nil) then append(stashesReady,steps[0]^.operation^.writesStash);

    for i:=1 to length(steps)-1 do begin
      if (steps[i]^.operation^.dependsOnImageBefore and (steps[i-1]^.outputImage=nil))
      or ((steps[i]^.operation^.readsStash<>'') and not(arrContains(stashesReady,steps[i]^.operation^.readsStash)))
      then begin
        steps[i]^.clearOutputImage;
        dropValues(stashesReady,steps[i]^.operation^.writesStash);
      end;
      if (steps[i]^.outputImage<>nil) and (steps[i]^.operation^.writesStash<>'') then append(stashesReady,steps[i]^.operation^.writesStash);
    end;
  end;

PROCEDURE T_editorWorkflow.stepChanged(CONST index: longint);
  begin
    stopBeforeEditing(index,index);
    enterCriticalSection(contextCS);
    try
      if (index>=0) and (index<length(steps)) then begin
        step[index]^.refreshSpecString;
        step[index]^.clearOutputImage;
        checkStepIO;
      end;
    finally
      leaveCriticalSection(contextCS);
    end;
  end;

FUNCTION T_simpleWorkflow.addStep(CONST specification: string; CONST atIndex:longint): boolean;
  VAR newStep:P_workflowStep;
  begin
    new(newStep,create(specification));
    if newStep^.isValid then begin
      addStep(newStep,atIndex);
      result:=true;
    end else begin
      messageQueue^.Post('Invalid step was rejected: '+specification,true,-1,0);
      dispose(newStep,destroy);
      result:=false;
    end;
  end;

PROCEDURE T_simpleWorkflow.addStep(CONST operation: P_imageOperation; CONST atIndex:longint);
  VAR newStep:P_workflowStep;
  begin
    new(newStep,create(operation));
    addStep(newStep,atIndex);
  end;

PROCEDURE T_simpleWorkflow.addStep(CONST newStep:P_workflowStep; CONST atIndex:longint);
  VAR i:longint;
      at:longint;
  begin
    enterCriticalSection(contextCS);
    try
      setLength(steps,length(steps)+1);
      if atIndex>=length(steps) then at:=length(steps)-1
      else if atIndex<=0        then at:=0
      else                           at:=atIndex;
      for i:=length(steps)-1 downto at+1 do steps[i]:=steps[i-1];
      steps[at]:=newStep;
      newStep^.clearOutputImage;
      checkStepIO;
    finally
      leaveCriticalSection(contextCS);
    end;
  end;

PROCEDURE T_editorWorkflow.swapStepDown(CONST firstIndex,lastIndex:longint);
  VAR tmp:P_workflowStep;
      index:longint;
  begin
    if (firstIndex>=0) and (firstIndex<=lastIndex) and (lastIndex<length(steps)-1) then begin
      stopBeforeEditing(firstIndex,lastIndex+1);
      enterCriticalSection(contextCS);
      try
        for index:=lastIndex downto firstIndex do begin
          tmp           :=steps[index  ];
          steps[index  ]:=steps[index+1];
          steps[index+1]:=tmp;
          if isValid then stepChanged(index)
                     else stepChanged(0);
        end;
      finally
        leaveCriticalSection(contextCS);
      end;
    end;
  end;

PROCEDURE T_editorWorkflow.removeStep(CONST firstIndex,lastIndex:longint);
  VAR i:longint;
      delta:longint;
  begin
    if (firstIndex>=0) and (firstIndex<=lastIndex) and (lastIndex<length(steps)) then begin
      stopBeforeEditing(firstIndex,lastIndex);
      enterCriticalSection(contextCS);
      try
        delta:=lastIndex-firstIndex+1;
        for i:=firstIndex to lastIndex do dispose(steps[i],destroy);
        for i:=firstIndex to length(steps)-1-delta do steps[i]:=steps[i+delta];
        setLength(steps,length(steps)-delta);
        if isValid and (firstIndex<length(steps)) then begin
          if steps[firstIndex]^.operation^.dependsOnImageBefore then begin
            steps[firstIndex]^.clearOutputImage;
            checkStepIO;
          end;
        end;
      finally
        leaveCriticalSection(contextCS);
      end;
    end;
  end;

FUNCTION T_editorWorkflow.isEditorWorkflow: boolean;
  begin
    result:=true;
  end;

FUNCTION T_editorWorkflow.getSerialVersion: dword;
  begin
    result:=234814109;
  end;

FUNCTION T_editorWorkflow.loadFromStream(VAR stream: T_bufferedInputStreamWrapper): boolean;
  VAR count:longint;
      i:longint;
  begin
    result:=inherited;
    result:=result and config.loadFromStream(stream);
    if not(result) then exit(false);
    count:=stream.readNaturalNumber;
    setLength(steps,count);
    for i:=0 to length(steps)-1 do steps[i]:=nil;
    for i:=0 to length(steps)-1 do if result then begin
      new(steps[i],initializeForReadingFromStream);
      result:=result and steps[i]^.loadFromStream(stream);
    end;
    result:=result and stream.allOkay;
    if result then exit(true);

    for i:=0 to length(steps)-1 do if steps[i]<>nil then dispose(steps[i],destroy);
    setLength(steps,0);
  end;

PROCEDURE T_editorWorkflow.saveToStream(VAR stream: T_bufferedOutputStreamWrapper);
  VAR i:longint;
  begin
    inherited;
    config.saveToStream(stream);
    stream.writeNaturalNumber(length(steps));
    for i:=0 to length(steps)-1 do steps[i]^.saveToStream(stream);
  end;

FUNCTION T_simpleWorkflow.workflowType: T_workflowType;
  VAR startFixed:boolean;
      endFixed  :boolean;
  begin
    if (length(steps)<=0) or not(isValid) then exit(wft_empty_or_unknown);
    startFixed:=(steps[0]^.operation^.readsFile<>'') or isResizeOperation(steps[0]^.operation);
    endFixed  :=(steps[stepCount-1]^.operation^.writesFile<>'');
    if startFixed then begin
      if endFixed
      then result:=wft_fixated
      else result:=wft_halfFix;
    end else begin
      if step[0]^.operation^.dependsOnImageBefore
      then begin
        if endFixed
        then result:=wft_manipulativeWithSave
        else result:=wft_manipulative
      end else begin
        if endFixed
        then result:=wft_generativeWithSave
        else result:=wft_generative;
      end;
    end;
  end;

FUNCTION T_simpleWorkflow.proposedImageFileName(CONST resString: ansistring): string;
  VAR i:longint;
      newExt:ansistring;
  begin
    if (length(steps)>1) then begin
      result:=steps[length(steps)-1]^.operation^.writesFile;
      if result<>'' then exit(result);
    end;
    if (workflowType<>wft_generative) or (resString='')
    then newExt:=''
    else newExt:='_'+resString;
    result:=ChangeFileExt(config.workflowFilename,newExt+lowercase(JPG_EXT));
    if fileExists(result) then begin
      i:=0;
      repeat
        inc(i);
        result:=ChangeFileExt(config.workflowFilename,newExt+'_'+intToStr(i)+lowercase(JPG_EXT));
      until not(fileExists(result))
    end;
  end;

FUNCTION T_simpleWorkflow.isValid: boolean;
  VAR s:P_workflowStep;
      i,j:longint;
      stashId:string;
      fileName:string;
      writtenBeforeRead:boolean;
  begin
    //Every single step has to be valid
    for s in steps do if not(s^.isValid) then exit(false);
    //Reading stash access must not take place before writing
    result:=true;
    for i:=0 to length(steps)-1 do begin
      stashId:=steps[i]^.operation^.readsStash;
      if stashId<>'' then begin
        writtenBeforeRead:=false;
        for j:=0 to i-1 do writtenBeforeRead:=writtenBeforeRead or (steps[j]^.operation^.writesStash=stashId);
        if not(writtenBeforeRead) then begin
          messageQueue^.Post('Stash "'+stashId+'" is read before it is written',true,i,stepCount);
          result:=false;
        end;
      end;

      fileName:=steps[i]^.operation^.readsFile;
      if (fileName<>'') and not(fileExists(fileName)) then begin
        messageQueue^.Post('File "'+fileName+'" does not exist so it cannot be loaded',true,i,stepCount);
        result:=false;
      end;

      if not(isEditorWorkflow) then begin
        fileName:=steps[i]^.operation^.writesFile;
        if  (fileName<>'') and fileExists(fileName) then begin
          messageQueue^.Post('File "'+fileName+'" already exists. The workflow will not be exeuted to prevent overwriting.',true,i,stepCount);
          result:=false;
        end;
      end;
    end;
  end;

FUNCTION T_simpleWorkflow.limitedDimensionsForResizeStep(CONST tgtDim: T_imageDimensions): T_imageDimensions;
  begin
    result:=config.limitedDimensionsForResizeStep(tgtDim);
  end;

FUNCTION T_simpleWorkflow.limitImageSize: boolean;
  begin
    result:=config.limitImageSize(image);
  end;

PROCEDURE T_simpleWorkflow.configChanged;
  begin
    //no op...
  end;

PROCEDURE T_editorWorkflow.configChanged;
  VAR i:longint;
  begin
    ensureStop;
    enterCriticalSection(contextCS);
    try
      for i:=0 to length(steps)-1 do begin
        step[i]^.refreshSpecString;
        step[i]^.clearOutputImage;
      end;
    finally
      leaveCriticalSection(contextCS);
    end;
  end;

CONSTRUCTOR T_editorWorkflow.createEditorWorkflow(
  CONST messageQueue_: P_structuredMessageQueue);
  begin
    inherited createContext(messageQueue_);
    config.create(@configChanged);
    setLength(steps,0);
  end;

end.
