UNIT workflowSteps;
INTERFACE
USES
  myParams,
  mypics,
  imageContexts,
  ExtCtrls,
  serializationUtil;
TYPE
P_workflowStep=^T_workflowStep;

{ T_workflowStep }

T_workflowStep=object(T_serializable)
  private
    specString   :string;
    valid        :boolean;
    operation_   :P_imageOperation;
    outputPreview_: TImage;
    outputHash_   : longword;
    PROCEDURE setSpecification(CONST spec:string);
  public
    outputImage: P_rawImage;
    CONSTRUCTOR create(CONST spec:string);
    CONSTRUCTOR create(CONST op:P_imageOperation);
    CONSTRUCTOR initializeForReadingFromStream;
    DESTRUCTOR destroy;
    PROCEDURE execute(CONST context:P_abstractWorkflow);
    PROPERTY specification:string read specString write setSpecification;
    PROPERTY isValid:boolean read valid;
    PROPERTY operation:P_imageOperation read operation_;
    PROCEDURE clearOutputImage;
    PROCEDURE saveOutputImage(VAR image:T_rawImage);
    FUNCTION toStringPart(CONST configPart:boolean):string;
    FUNCTION hasComplexParameterDescription:boolean;
    PROCEDURE refreshSpecString;
    FUNCTION outputPreview:TImage;
    PROPERTY outputHash:longword read outputHash_;
    FUNCTION getSerialVersion:dword; virtual;
    FUNCTION loadFromStream(VAR stream:T_bufferedInputStreamWrapper):boolean; virtual;
    PROCEDURE saveToStream(VAR stream:T_bufferedOutputStreamWrapper); virtual;
end;

IMPLEMENTATION
VAR next_hash:longword=0;
PROCEDURE T_workflowStep.setSpecification(CONST spec: string);
  begin
    if specString=spec then exit;
    specString:=spec;
    if (operation_<>nil) then dispose(operation_,destroy);
    operation_:=parseOperation(specString);
    valid:=operation_<>nil;
    {$ifdef debugMode}writeln(stdErr,'DEBUG T_workflowStep.setSpecification "'+spec+'" [valid=',valid,']');{$endif}
    clearOutputImage;
  end;

CONSTRUCTOR T_workflowStep.create(CONST spec: string);
  begin
    operation_:=nil;
    setSpecification(spec);
    outputImage:=nil; outputPreview_:=nil; outputHash_:=0;
  end;

CONSTRUCTOR T_workflowStep.create(CONST op: P_imageOperation);
  begin
    operation_:=op;
    specString:=op^.toString(tsm_withNiceParameterName);
    valid     :=true;
    outputImage:=nil; outputPreview_:=nil; outputHash_:=0;
  end;

CONSTRUCTOR T_workflowStep.initializeForReadingFromStream;
  begin
    operation_:=nil;
    specString:='';
    valid     :=false;
    outputImage:=nil;
    outputPreview_:=nil;
    outputHash_:=0;
  end;

DESTRUCTOR T_workflowStep.destroy;
  begin
    clearOutputImage;
    if (operation_<>nil) then dispose(operation_,destroy);
  end;

PROCEDURE T_workflowStep.execute(CONST context: P_abstractWorkflow);
  begin
    if valid then begin
      if outputImage=nil then begin
        context^.messageQueue^.Post(specification,false,context^.currentStepIndex,context^.stepCount);
        operation_^.execute(context);
      end else begin
        context^.image.copyFromPixMap(outputImage^);
      end;

    end else begin
      context^.cancelWithError('Invalid step: '+specification);
    end;
  end;

PROCEDURE T_workflowStep.clearOutputImage;
  begin
    if outputImage<>nil then dispose(outputImage,destroy);
    outputImage:=nil;
    if outputPreview_<>nil then begin
      outputPreview_.destroy;
      outputPreview_:=nil;
    end;
    outputHash_:=0;
  end;

PROCEDURE T_workflowStep.saveOutputImage(VAR image: T_rawImage);
  begin
    if outputImage=nil
    then new(outputImage,create(image))
    else outputImage^.copyFromPixMap(image);
    outputHash_:=interLockedIncrement(next_hash);
  end;

FUNCTION T_workflowStep.toStringPart(CONST configPart: boolean): string;
  begin
    if operation=nil then begin
      if configPart
      then result:=specification
      else result:='<invalid>';
    end else begin
      if configPart
      then begin
        result:=operation^.toString(tsm_withoutParameterName);
      end else begin
        result:=operation^.meta^.getName;
      end;
    end;
  end;

FUNCTION T_workflowStep.hasComplexParameterDescription: boolean;
  begin
    result:=isValid and ((operation^.meta^.category=imc_generation)
                      or (operation^.meta^.getSimpleParameterDescription<>nil)
                     and (operation^.meta^.getSimpleParameterDescription^.subCount>0));
  end;

PROCEDURE T_workflowStep.refreshSpecString;
  begin
    if operation_<>nil then specString:=operation_^.toString(tsm_withNiceParameterName);
  end;

FUNCTION T_workflowStep.outputPreview: TImage;
  begin
    if (outputPreview_=nil) and (outputImage<>nil) then begin
      outputPreview_:=TImage.create(nil);
      outputImage^.copyToImage(outputPreview_);
    end;
    result:=outputPreview_;
  end;

FUNCTION T_workflowStep.getSerialVersion: dword;
  begin
    result:=345871;
  end;

FUNCTION T_workflowStep.loadFromStream(VAR stream: T_bufferedInputStreamWrapper): boolean;
  begin
    clearOutputImage;
    specString:=stream.readAnsiString;
    if (operation_<>nil) then dispose(operation_,destroy);
    operation_:=parseOperation(specString);
    valid:=operation_<>nil;
    result:=valid;
  end;

PROCEDURE T_workflowStep.saveToStream(VAR stream: T_bufferedOutputStreamWrapper);
  begin
    if valid then stream.writeAnsiString(specString);
  end;

end.

