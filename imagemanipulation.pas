UNIT imageManipulation;
INTERFACE
USES myParams,
     imageContexts;
TYPE
T_simpleOperationKind=(sok_inputDependent,
                       sok_inputIndependent,
                       sok_combiningStash,
                       sok_restoringStash,
                       sok_writingStash,
                       sok_writingFile,
                       sok_readingFile);
F_simpleImageOperation=PROCEDURE(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
P_simpleImageOperationMeta=^T_simpleImageOperationMeta;
T_simpleImageOperationMeta=object(T_imageOperationMeta)
  private
    kind      :T_simpleOperationKind;
    operation:F_simpleImageOperation;
  protected
    signature:P_parameterDescription;
  public
    CONSTRUCTOR create(CONST cat_:T_imageManipulationCategory; CONST sig:P_parameterDescription; CONST op:F_simpleImageOperation; CONST simpleOperationKind:T_simpleOperationKind);
    DESTRUCTOR destroy; virtual;
    FUNCTION parse(CONST specification:ansistring):P_imageOperation; virtual;
    FUNCTION getSimpleParameterDescription:P_parameterDescription; virtual;
    FUNCTION getDefaultOperation:P_imageOperation; virtual;
  end;

P_simpleImageOperation=^T_simpleImageOperation;
T_simpleImageOperation=object(T_imageOperation)
  private
    parameters:T_parameterValue;
  public
    CONSTRUCTOR create(CONST meta_:P_simpleImageOperationMeta; CONST parameters_:T_parameterValue);
    PROCEDURE execute(CONST context:P_abstractWorkflow); virtual;
    FUNCTION getSimpleParameterValue:P_parameterValue; virtual;
    FUNCTION isSingleton:boolean; virtual;
    DESTRUCTOR destroy; virtual;
    FUNCTION readsStash:string; virtual;
    FUNCTION writesStash:string; virtual;
    FUNCTION readsFile:string; virtual;
    FUNCTION writesFile:string; virtual;
    FUNCTION dependsOnImageBefore:boolean; virtual;
    FUNCTION toString(nameMode:T_parameterNameMode):string; virtual;
    FUNCTION alterParameter(CONST newParameterString:string):boolean; virtual;
  end;

T_deleteFileMeta=object(T_simpleImageOperationMeta)
  public
    CONSTRUCTOR create;
    FUNCTION getOperationToDeleteFile(CONST fileName:string):P_simpleImageOperation;
  end;

FUNCTION registerSimpleOperation(CONST cat_:T_imageManipulationCategory; CONST sig:P_parameterDescription; CONST op:F_simpleImageOperation; CONST kind:T_simpleOperationKind=sok_inputDependent):P_simpleImageOperationMeta;
FUNCTION canParseSizeLimit(CONST s:string; OUT size:longint):boolean;
FUNCTION getSaveStatement(CONST savingToFile:string; CONST savingWithSizeLimit:longint):P_simpleImageOperation;
VAR deleteOp:T_deleteFileMeta;
IMPLEMENTATION
USES generationBasics,sysutils;
VAR pd_save                :P_simpleImageOperationMeta=nil;
    pd_save_with_size_limit:P_simpleImageOperationMeta=nil;

FUNCTION registerSimpleOperation(CONST cat_:T_imageManipulationCategory; CONST sig:P_parameterDescription; CONST op:F_simpleImageOperation; CONST kind:T_simpleOperationKind=sok_inputDependent):P_simpleImageOperationMeta;
  begin
    new(result,create(cat_,sig,op,kind));
    registerOperation(result);
  end;

FUNCTION canParseSizeLimit(CONST s: string; OUT size: longint): boolean;
  VAR p:T_parameterValue;
  begin
    p.createToParse(pd_save_with_size_limit^.getSimpleParameterDescription,'dummy.jpg@'+s);
    size:=p.i0;
    result:=p.isValid;
  end;

FUNCTION getSaveStatement(CONST savingToFile: string; CONST savingWithSizeLimit: longint): P_simpleImageOperation;
  begin
    if (uppercase(extractFileExt(savingToFile))=SIZE_LIMITABLE_EXTENSION) and (savingWithSizeLimit>0) then begin
      result:=P_simpleImageOperation(pd_save_with_size_limit^.getDefaultOperation);
      result^.parameters.fileName:=savingToFile;
      result^.parameters.modifyI(0,savingWithSizeLimit);
    end else begin
      result:=P_simpleImageOperation(pd_save^.getDefaultOperation);
      result^.parameters.fileName:=savingToFile;
    end;
    if not(result^.parameters.isValid) then begin
      dispose(result,destroy);
      result:=nil;
      assert(false,'save statement must be valid');
    end;
  end;

CONSTRUCTOR T_simpleImageOperation.create(
  CONST meta_: P_simpleImageOperationMeta; CONST parameters_: T_parameterValue);
  begin
    inherited create(meta_);
    parameters:=parameters_;
  end;

PROCEDURE T_simpleImageOperation.execute(CONST context: P_abstractWorkflow);
  begin
    P_simpleImageOperationMeta(meta)^.operation(parameters,context);
  end;

FUNCTION T_simpleImageOperation.getSimpleParameterValue: P_parameterValue;
  begin
    result:=@parameters;
  end;

FUNCTION T_simpleImageOperation.isSingleton: boolean;
  begin
    result:=false;
  end;

DESTRUCTOR T_simpleImageOperation.destroy;
  begin
    inherited destroy;
  end;

FUNCTION T_simpleImageOperation.readsStash: string;
  begin
    if P_simpleImageOperationMeta(meta)^.kind in [sok_combiningStash,sok_restoringStash]
    then result:=parameters.fileName
    else result:='';
  end;

FUNCTION T_simpleImageOperation.writesStash: string;
  begin
    if P_simpleImageOperationMeta(meta)^.kind=sok_writingStash
    then result:=parameters.fileName
    else result:='';
  end;

FUNCTION T_simpleImageOperation.readsFile: string;
  begin
    if P_simpleImageOperationMeta(meta)^.kind=sok_readingFile
    then result:=parameters.fileName
    else result:='';
  end;

FUNCTION T_simpleImageOperation.writesFile: string;
  begin
    if P_simpleImageOperationMeta(meta)^.kind=sok_writingFile
    then result:=parameters.fileName
    else result:='';
  end;

FUNCTION T_simpleImageOperation.dependsOnImageBefore: boolean;
  begin
    result:=P_simpleImageOperationMeta(meta)^.kind in [sok_inputDependent,sok_combiningStash,sok_writingStash];
  end;

FUNCTION T_simpleImageOperation.toString(nameMode: T_parameterNameMode): string;
  begin
    result:=parameters.toString(nameMode);
  end;

FUNCTION T_simpleImageOperation.alterParameter(CONST newParameterString: string
  ): boolean;
  begin
    result:= parameters.canParse(newParameterString);
  end;

CONSTRUCTOR T_simpleImageOperationMeta.create(
  CONST cat_: T_imageManipulationCategory; CONST sig: P_parameterDescription;
  CONST op: F_simpleImageOperation;
  CONST simpleOperationKind: T_simpleOperationKind);
  begin
    inherited create(sig^.getName,cat_);
    signature:=sig;
    operation:=op;
    kind:=simpleOperationKind;
  end;

DESTRUCTOR T_simpleImageOperationMeta.destroy;
  begin
    inherited destroy;
    dispose(signature,destroy);
  end;

FUNCTION T_simpleImageOperationMeta.parse(CONST specification: ansistring): P_imageOperation;
  VAR value:T_parameterValue;
      op:P_simpleImageOperation;
  begin
    value.createToParse(signature,specification,tsm_withNiceParameterName);
    if value.isValid then begin
      new(op,create(@self,value));
      result:=op;
    end else result:=nil;
  end;

FUNCTION T_simpleImageOperationMeta.getSimpleParameterDescription: P_parameterDescription;
  begin
    result:=signature;
  end;

FUNCTION T_simpleImageOperationMeta.getDefaultOperation: P_imageOperation;
  VAR op:P_simpleImageOperation;
  begin
    new(op,create(@self,signature^.getDefaultParameterValue));
    result:=op;
  end;

PROCEDURE loadImage_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  begin
    try
      context^.image.loadFromFile(parameters.fileName);
    except
      context^.cancelWithError('Error trying to load '+parameters.fileName);
    end;
  end;

PROCEDURE saveImage_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  begin
    if context^.isEditorWorkflow then begin
      context^.messageQueue^.Post('No images are saved in editor mode',false,context^.currentStepIndex,context^.stepCount);
      exit;
    end;
    try
      if parameters.description^.getType=pt_jpgNameWithSize
      then context^.image.saveJpgWithSizeLimit(parameters.fileName,parameters.i0)
      else context^.image.saveToFile(parameters.fileName);
    except
      context^.cancelWithError('Error trying to save '+parameters.fileName);
    end;
  end;

PROCEDURE deleteFile_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  begin
    if context^.isEditorWorkflow then begin
      context^.cancelWithError('"delete" is not expected in editor mode');
      exit;
    end;
    DeleteFile(parameters.fileName);
  end;

CONSTRUCTOR T_deleteFileMeta.create;
  begin
    inherited create(imc_misc,newParameterDescription('delete',pt_fileName)^.setDefaultValue('123'+lowercase(C_todoExtension)),@deleteFile_impl,sok_inputIndependent);
  end;

FUNCTION T_deleteFileMeta.getOperationToDeleteFile(CONST fileName: string): P_simpleImageOperation;
  VAR value:T_parameterValue;
      op:P_simpleImageOperation;
  begin
    value.createFromValue(signature,fileName);
    new(op,create(@self,value));
    result:=op;
  end;

INITIALIZATION
  registerSimpleOperation(imc_imageAccess,
                          newParameterDescription(C_loadStatementName,pt_fileName)^.setDefaultValue('filename.jpg'),
                          @loadImage_impl,
                          sok_readingFile);
  pd_save:=
  registerSimpleOperation(imc_imageAccess,
                          newParameterDescription('save',pt_fileName)^.setDefaultValue('filename.jpg'),
                          @saveImage_impl,
                          sok_writingFile);
  pd_save_with_size_limit:=
  registerSimpleOperation(imc_imageAccess,
                          newParameterDescription('save',pt_jpgNameWithSize)^.setDefaultValue('image.jpg@1M'),
                          @saveImage_impl,
                          sok_writingFile);
  deleteOp.create;
FINALIZATION
  deleteOp.destroy;

end.

