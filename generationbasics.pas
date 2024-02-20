UNIT generationBasics;
INTERFACE
USES pixMaps,
     mypics,
     myGenerics,
     serializationUtil,
     refCountedImages;
CONST
    C_workflowExtension='.WF';
    C_todoExtension='.TODO';
    C_nullSourceOrTargetFileName='-';
    C_loadStatementName='load';
    C_resizeStatementName='resize';
TYPE
  F_simpleCallback=PROCEDURE of object;
  P_imageWorkflowConfiguration=^T_imageWorkflowConfiguration;

  { T_imageWorkflowConfiguration }

  T_imageWorkflowConfiguration=object(T_serializable)
    private
      //Varying over config lifetime:
      initialImageFilename             :string;
      fInitialResolution,
      fImageSizeLimit                  :T_imageDimensions;
      cachedInitialImageWasScaled      :boolean;
      cachedInitialImage               :P_referenceCountedImage;
      onConfigChanged                  :F_simpleCallback;
      PROCEDURE clearImage;
      PROCEDURE setInitialResolution(CONST res:T_imageDimensions);
      PROCEDURE setMaximumResolution(CONST res:T_imageDimensions);
    public
      workflowFilename:string;
      intermediateResultsPreviewQuality:boolean;
      CONSTRUCTOR create(CONST step0Changed:F_simpleCallback);
      CONSTRUCTOR clone(CONST original:T_imageWorkflowConfiguration);
      PROCEDURE copyFrom(CONST original:T_imageWorkflowConfiguration);
      DESTRUCTOR destroy;
      PROCEDURE setDefaults;
      PROCEDURE setInitialImage     (VAR image:T_rawImage);
      PROCEDURE setInitialImage     (CONST fileName:string);
      PROCEDURE prepareImageForWorkflow(VAR image:T_rawImage);
      FUNCTION getFirstTodoStep:string;
      FUNCTION trueInitialResolution:T_imageDimensions;
      {Returns true if the image was modified}
      FUNCTION limitImageSize(VAR image:T_rawImage):boolean;
      FUNCTION limitImageSize(VAR image:P_referenceCountedImage):boolean;
      FUNCTION limitedDimensionsForResizeStep(CONST tgtDim:T_imageDimensions):T_imageDimensions;
      PROPERTY sizeLimit        :T_imageDimensions read fImageSizeLimit    write setMaximumResolution;
      PROPERTY initialResolution:T_imageDimensions read fInitialResolution write setInitialResolution;
      PROPERTY initialImageName:string read initialImageFilename;
      FUNCTION associatedDirectory:string;
      FUNCTION getSerialVersion:dword; virtual;
      FUNCTION loadFromStream(VAR stream:T_bufferedInputStreamWrapper):boolean; virtual;
      PROCEDURE saveToStream(VAR stream:T_bufferedOutputStreamWrapper); virtual;
  end;

  P_structuredMessage=^T_structuredMessage;
  T_structuredMessage=object
    private
      fMessageCreatedAtTime:double;
      fIndicatesError:boolean;
      fStepIndex:longint;
      fTotalSteps:longint;
      fMessageText:string;
      nextMessage:P_structuredMessage;
    public
      CONSTRUCTOR create(CONST message:string; CONST isError:boolean=false; CONST relatesToStep:longint=-1; CONST numberOfSteps:longint=0);
      DESTRUCTOR destroy;
      FUNCTION toString(CONST messageStringLengthLimit:longint):string;
      PROPERTY messageText:string read fMessageText;
      PROPERTY stepIndex:longint read fStepIndex;
      PROPERTY indicatesError:boolean read fIndicatesError;
      PROPERTY getTime:double read fMessageCreatedAtTime;
  end;

  P_structuredMessageQueue=^T_structuredMessageQueue;
  T_structuredMessageQueue=object
    private
      queueCs:TRTLCriticalSection;
      first,last:P_structuredMessage;
    public
      messageStringLengthLimit:longint;
      CONSTRUCTOR create;
      DESTRUCTOR destroy;
      FUNCTION get:P_structuredMessage;
      PROCEDURE postSeparator;
      PROCEDURE Post(CONST message:string; CONST isError:boolean; CONST relatesToStep,totalStepsInWorkflow:longint);
      PROCEDURE clear;
      FUNCTION getText:T_arrayOfString;
  end;

IMPLEMENTATION
USES sysutils;

FUNCTION stringEllipse(CONST s:string; CONST messageStringLengthLimit:longint):string;
  begin
    if length(s)>messageStringLengthLimit
    then result:=copy(s,1,messageStringLengthLimit-3)+'...'
    else result:=s;
  end;

CONSTRUCTOR T_structuredMessageQueue.create;
  begin
    initCriticalSection(queueCs);
    first:=nil;
    last:=nil;
    messageStringLengthLimit:=100;
  end;

PROCEDURE T_structuredMessageQueue.clear;
  VAR m:P_structuredMessage;
  begin
    enterCriticalSection(queueCs);
    try
      m:=get;
      while m<>nil do begin
        dispose(m,destroy);
        m:=get;
      end;
    finally
      leaveCriticalSection(queueCs);
    end;
  end;

DESTRUCTOR T_structuredMessageQueue.destroy;
  begin
    clear;
    doneCriticalSection(queueCs);
  end;

FUNCTION T_structuredMessageQueue.get: P_structuredMessage;
  begin
    enterCriticalSection(queueCs);
    try
      result:=first;
      if first <>nil then first:=first^.nextMessage;
      if result<>nil then result^.nextMessage:=nil;
    finally
      leaveCriticalSection(queueCs);
    end;
  end;

FUNCTION T_structuredMessageQueue.getText:T_arrayOfString;
  VAR m:P_structuredMessage;
  begin
    initialize(result);
    setLength(result,0);
    enterCriticalSection(queueCs);
    while first<>nil do begin
      append(result,first^.toString(messageStringLengthLimit));
      m:=first;
      first:=first^.nextMessage;
      dispose(m,destroy);
    end;
    leaveCriticalSection(queueCs);
  end;
CONST C_SEPERATOR_MESSAGE_TEXT='''';

PROCEDURE T_structuredMessageQueue.postSeparator;
  begin
    Post(C_SEPERATOR_MESSAGE_TEXT,false,-1,0);
  end;

PROCEDURE T_structuredMessageQueue.Post(CONST message:string; CONST isError:boolean; CONST relatesToStep,totalStepsInWorkflow:longint);
  VAR m:P_structuredMessage;
  begin
    enterCriticalSection(queueCs);
    try
      new(m,create(message,isError,relatesToStep,totalStepsInWorkflow));
      if first=nil
      then first:=m
      else last^.nextMessage:=m;
      last:=m;
      {$ifdef debugMode}
      writeln(stdErr,'DEBUG T_structuredMessageQueue.Post: ',m^.toString(maxLongint));
      {$endif}
    finally
      leaveCriticalSection(queueCs);
    end;
  end;

CONSTRUCTOR T_structuredMessage.create(CONST message: string; CONST isError: boolean; CONST relatesToStep: longint; CONST numberOfSteps:longint);
  begin
    fMessageCreatedAtTime:=now;
    fMessageText:=message;
    fIndicatesError:=isError;
    fStepIndex:=relatesToStep;
    fTotalSteps:=numberOfSteps;
    nextMessage:=nil;
  end;

DESTRUCTOR T_structuredMessage.destroy;
  begin
  end;

FUNCTION T_structuredMessage.toString(CONST messageStringLengthLimit:longint): string;
  begin
    if fMessageText=C_SEPERATOR_MESSAGE_TEXT then exit('');
    result:=FormatDateTime('hh:mm:ss',fMessageCreatedAtTime)+' ';
    if (fStepIndex>=0) then result+='('+intToStr(fStepIndex+1)+'/'+intToStr(fTotalSteps)+') ';
    if fIndicatesError then result+='ERROR: ';
    result:=stringEllipse(result+fMessageText,messageStringLengthLimit);
  end;

PROCEDURE T_imageWorkflowConfiguration.clearImage;
  begin
    disposeRCImage(cachedInitialImage);
    cachedInitialImageWasScaled:=false;
  end;

CONSTRUCTOR T_imageWorkflowConfiguration.create(CONST step0Changed: F_simpleCallback);
  begin
    onConfigChanged:=step0Changed;
    cachedInitialImage:=nil;
    setDefaults;
  end;

CONSTRUCTOR T_imageWorkflowConfiguration.clone(CONST original:T_imageWorkflowConfiguration);
  begin
    onConfigChanged:=nil;
    initialImageFilename             :=original.initialImageFilename             ;
    fInitialResolution               :=original.fInitialResolution               ;
    fImageSizeLimit                  :=original.fImageSizeLimit                  ;
    cachedInitialImageWasScaled      :=original.cachedInitialImageWasScaled      ;
    cachedInitialImage               :=rereference(original.cachedInitialImage)  ;
    workflowFilename                 :=original.workflowFilename                 ;
    intermediateResultsPreviewQuality:=original.intermediateResultsPreviewQuality;
  end;

PROCEDURE T_imageWorkflowConfiguration.copyFrom(CONST original:T_imageWorkflowConfiguration);
  begin
    clearImage;
    initialImageFilename             :=original.initialImageFilename             ;
    fInitialResolution               :=original.fInitialResolution               ;
    fImageSizeLimit                  :=original.fImageSizeLimit                  ;
    cachedInitialImageWasScaled      :=original.cachedInitialImageWasScaled      ;
    cachedInitialImage               :=rereference(original.cachedInitialImage)  ;
    workflowFilename                 :=original.workflowFilename                 ;
    intermediateResultsPreviewQuality:=original.intermediateResultsPreviewQuality;
  end;

DESTRUCTOR T_imageWorkflowConfiguration.destroy;
  begin
    clearImage;
  end;

PROCEDURE T_imageWorkflowConfiguration.setDefaults;
  begin
    workflowFilename                 :='';
    initialImageFilename             :='';
    intermediateResultsPreviewQuality:=false;
    fInitialResolution               :=imageDimensions(1920,1080);
    fImageSizeLimit                  :=C_maxImageDimensions;
    clearImage;
  end;

PROCEDURE T_imageWorkflowConfiguration.setInitialResolution(
  CONST res: T_imageDimensions);
  begin
    if fInitialResolution=res then exit;
    fInitialResolution:=res;
    fImageSizeLimit:=fImageSizeLimit.max(fInitialResolution);
    if onConfigChanged<>nil then onConfigChanged();
  end;

PROCEDURE T_imageWorkflowConfiguration.setMaximumResolution(
  CONST res: T_imageDimensions);
  begin
    if sizeLimit=res then exit;
    fImageSizeLimit:=res;
    fInitialResolution:=fImageSizeLimit.min(fInitialResolution);
    if onConfigChanged<>nil then onConfigChanged();
  end;

PROCEDURE T_imageWorkflowConfiguration.setInitialImage(
  VAR image: T_rawImage);
  begin
    clearImage;
    new(cachedInitialImage,create(image));
    initialImageFilename:=C_nullSourceOrTargetFileName;
    if onConfigChanged<>nil then onConfigChanged();
  end;

PROCEDURE T_imageWorkflowConfiguration.setInitialImage(CONST fileName: string);
  begin
    if fileName=initialImageFilename then exit;
    clearImage;
    initialImageFilename:=fileName;
    if onConfigChanged<>nil then onConfigChanged();
  end;

PROCEDURE T_imageWorkflowConfiguration.prepareImageForWorkflow(VAR image: T_rawImage);
  FUNCTION reloadInitialImage:boolean;
    begin
      new(cachedInitialImage,createFromFileName(initialImageFilename));
      cachedInitialImageWasScaled:=false;
      if (cachedInitialImage^.image.pixelCount<=1) or not(cachedInitialImage^.image.successfullyLoaded) then begin
        image.resize(fInitialResolution,res_dataResize,not intermediateResultsPreviewQuality);
        image.drawCheckerboard;
        initialImageFilename:='';
        clearImage;
        result:=false;
      end else result:=true;
    end;
  begin
    if initialImageFilename<>'' then begin
      if initialImageFilename=C_nullSourceOrTargetFileName then begin
        //Special source without associated file
        image.copyFromPixMap(cachedInitialImage^.image);
        limitImageSize(image);
      end else begin
        if (cachedInitialImage=nil) and not(reloadInitialImage) then exit;
        if not(cachedInitialImage^.image.dimensions.fitsInto(fImageSizeLimit)) then begin
          //This block handles images being too large
          if cachedInitialImageWasScaled and not(reloadInitialImage) then exit;
          cachedInitialImageWasScaled:=limitImageSize(cachedInitialImage);
        end else if cachedInitialImageWasScaled
          and not((cachedInitialImage^.image.dimensions.height=fImageSizeLimit.height) or
                  (cachedInitialImage^.image.dimensions.width =fImageSizeLimit.width)) then begin
          //This block handles images being too small after a previous scaling
          if not(reloadInitialImage) then exit;
          cachedInitialImageWasScaled:=limitImageSize(cachedInitialImage);
        end;
        image.copyFromPixMap(cachedInitialImage^.image);
      end;
    end else begin
      image.resize(fInitialResolution,res_dataResize,not intermediateResultsPreviewQuality);
      image.drawCheckerboard;
    end;
  end;

FUNCTION T_imageWorkflowConfiguration.getFirstTodoStep: string;
  begin
    if (initialImageFilename<>'') and (initialImageFilename<>C_nullSourceOrTargetFileName)
    then result:=C_loadStatementName+':'+initialImageFilename
    else result:=C_resizeStatementName+':'+intToStr(fInitialResolution.width)+','+intToStr(fInitialResolution.height);
  end;

FUNCTION T_imageWorkflowConfiguration.trueInitialResolution:T_imageDimensions;
  begin
    if cachedInitialImage=nil
    then result:=fInitialResolution
    else result:=cachedInitialImage^.image.dimensions;
  end;

FUNCTION T_imageWorkflowConfiguration.limitImageSize(VAR image: T_rawImage): boolean;
  begin
    if image.dimensions.fitsInto(fImageSizeLimit) then exit(false);
    image.resize(fImageSizeLimit,res_fit,not intermediateResultsPreviewQuality);
    result:=true;
  end;

FUNCTION T_imageWorkflowConfiguration.limitImageSize(VAR image:P_referenceCountedImage):boolean;
  VAR otherImage:P_referenceCountedImage;
  begin
    if image^.image.dimensions.fitsInto(fImageSizeLimit) then exit(false);
    new(otherImage,create(image^.image));
    otherImage^.image.resize(fImageSizeLimit,res_fit,not intermediateResultsPreviewQuality);
    disposeRCImage(image);
    image:=otherImage;
    result:=true;
  end;

FUNCTION T_imageWorkflowConfiguration.limitedDimensionsForResizeStep(
  CONST tgtDim: T_imageDimensions): T_imageDimensions;
  begin
    if tgtDim.fitsInto(fImageSizeLimit) then exit(tgtDim);
    result:=fImageSizeLimit.getFittingRectangle(tgtDim.width/tgtDim.height);
  end;

FUNCTION T_imageWorkflowConfiguration.associatedDirectory: string;
  begin
    if workflowFilename=''
    then result:=paramStr(0)
    else result:=workflowFilename;
    result:=ExtractFileDir(result);
  end;

FUNCTION T_imageWorkflowConfiguration.getSerialVersion: dword;
  begin
    result:=1;
  end;

FUNCTION T_imageWorkflowConfiguration.loadFromStream(VAR stream: T_bufferedInputStreamWrapper): boolean;
  begin
    setDefaults;
    result:=inherited;
    initialImageFilename:=stream.readAnsiString;
    workflowFilename:=stream.readAnsiString;
    intermediateResultsPreviewQuality:=stream.readBoolean;
    result:=result and stream.allOkay;
  end;

PROCEDURE T_imageWorkflowConfiguration.saveToStream(VAR stream: T_bufferedOutputStreamWrapper);
  begin
    inherited;
    stream.writeAnsiString(initialImageFilename);
    stream.writeAnsiString(workflowFilename);
    stream.writeBoolean(intermediateResultsPreviewQuality);
  end;

end.

