UNIT im_geometry;
INTERFACE
USES pixMaps,imageManipulation,imageContexts,myParams;
CONST OP_NAME_CROP='crop';

TYPE

{ T_cropMeta }

T_cropMeta=object(T_simpleImageOperationMeta)
  public
    CONSTRUCTOR create;
    FUNCTION getOperationToCrop(CONST x0,x1,y0,y1:double):P_simpleImageOperation;
    FUNCTION getExpectedOutputResolution(CONST context:P_abstractWorkflow; CONST inputResolution:T_imageDimensions; CONST parameters:T_parameterValue):T_imageDimensions; virtual;
end;

{ T_rotateMeta }
P_rotateMeta=^T_rotateMeta;
T_rotateMeta=object(T_simpleImageOperationMeta)
  public
    CONSTRUCTOR create(CONST opName:string; CONST op:F_simpleImageOperation);
    FUNCTION getExpectedOutputResolution(CONST context:P_abstractWorkflow; CONST inputResolution:T_imageDimensions; CONST parameters:T_parameterValue):T_imageDimensions; virtual;
  end;

{ T_resizeMeta }
P_resizeMeta=^T_resizeMeta;
T_resizeMeta=object(T_simpleImageOperationMeta)
  public
    CONSTRUCTOR create(CONST opName:string; CONST op:F_simpleImageOperation);
    FUNCTION getExpectedOutputResolution(CONST context:P_abstractWorkflow; CONST inputResolution:T_imageDimensions; CONST parameters:T_parameterValue):T_imageDimensions; virtual;
  end;

VAR cropMeta:^T_cropMeta;
FUNCTION canParseResolution(CONST s:string; OUT dim:T_imageDimensions):boolean;
FUNCTION isResizeOperation(CONST op:P_imageOperation):boolean;
IMPLEMENTATION
USES mypics,sysutils;
VAR pd_resize:P_parameterDescription=nil;

FUNCTION canParseResolution(CONST s: string; OUT dim: T_imageDimensions): boolean;
  VAR p:T_parameterValue;
  begin
    p.createToParse(pd_resize,s);
    dim:=imageDimensions(p.i0,p.i1);
    result:=p.isValid;
  end;

FUNCTION isResizeOperation(CONST op:P_imageOperation):boolean;
  begin
    result:= op^.meta^.getSimpleParameterDescription=pd_resize;
  end;

FUNCTION targetDimensions(CONST parameters:T_parameterValue; CONST inputDim:T_imageDimensions; CONST context:P_abstractWorkflow):T_imageDimensions;
  VAR dim:T_imageDimensions;
  begin
    if parameters.flag
    then begin
      dim:=inputDim;
      dim.width :=round(dim.width *parameters.f0);
      dim.height:=round(dim.height*parameters.f0);
      result:=context^.limitedDimensionsForResizeStep(dim);
    end else result:=context^.limitedDimensionsForResizeStep(imageDimensions(parameters.i0,parameters.i1));
  end;

FUNCTION targetDimensions(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow):T_imageDimensions;
  begin
    result:=targetDimensions(parameters,context^.image.dimensions,context);
  end;

PROCEDURE resize_impl       (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_exact); end;
PROCEDURE fit_impl          (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_fit); end;
PROCEDURE fill_impl         (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_cropToFill); end;
PROCEDURE fitExpand_impl    (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_fitExpand); end;
PROCEDURE fitRotate_impl    (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_fitRotate); end;
PROCEDURE fillRotate_impl   (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_cropRotate); end;
PROCEDURE resizePxl_impl    (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_exactPixelate); end;
PROCEDURE fitPxl_impl       (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_fitPixelate); end;
PROCEDURE fillPxl_impl      (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_cropToFillPixelate); end;
PROCEDURE fitExpandPxl_impl (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_fitExpandPixelate); end;
PROCEDURE fitRotatePxl_impl (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_fitRotatePixelate); end;
PROCEDURE fillRotatePxl_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_cropRotatePixelate); end;

PROCEDURE crop_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  begin
    context^.image.crop(parameters.f0,parameters.f1,parameters.f2,parameters.f3);
    //context^.messageQueue^.Post('Dimensions after cropping are '+intToStr(context^.image.dimensions.width)+'x'+intToStr(context^.image.dimensions.height),false,context^.currentStepIndex,context^.stepCount);
  end;

PROCEDURE zoom_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  begin context^.image.zoom(parameters.f0); end;

PROCEDURE flip_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  begin context^.image.flip; end;

PROCEDURE flop_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  begin context^.image.flop; end;

PROCEDURE rotL_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  begin
    context^.image.rotLeft;
    context^.limitImageSize;
  end;

PROCEDURE rotR_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  begin
    context^.image.rotRight;
    context^.limitImageSize;
  end;

PROCEDURE rotDegrees_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  begin context^.image.rotate(parameters.f0); end;

FUNCTION resizeParameters(CONST name:string):P_parameterDescription;
  begin
    result:=newParameterDescription(name,pt_resizeParameter, 1, MAX_HEIGHT_OR_WIDTH)^
           .addChildParameterDescription(spa_i0,'width',pt_integer,1,MAX_HEIGHT_OR_WIDTH)^
           .addChildParameterDescription(spa_i1,'height',pt_integer,1,MAX_HEIGHT_OR_WIDTH)^
           .setDefaultValue('100x100');
  end;

{ T_resizeMeta }

CONSTRUCTOR T_resizeMeta.create(CONST opName: string; CONST op: F_simpleImageOperation);
  begin
    inherited create(imc_geometry,
                     resizeParameters(opName),
                     op,
                     sok_inputDependent)
  end;

FUNCTION T_resizeMeta.getExpectedOutputResolution(CONST context: P_abstractWorkflow; CONST inputResolution: T_imageDimensions; CONST parameters: T_parameterValue): T_imageDimensions;
  begin
    result:=targetDimensions(parameters,inputResolution,context);
  end;

{ T_rotateMeta }

CONSTRUCTOR T_rotateMeta.create(CONST opName: string; CONST op: F_simpleImageOperation);
  begin
    inherited create(imc_geometry,
                     newParameterDescription(opName, pt_none),
                     op,
                     sok_inputDependent);
  end;

FUNCTION T_rotateMeta.getExpectedOutputResolution(CONST context: P_abstractWorkflow; CONST inputResolution: T_imageDimensions; CONST parameters: T_parameterValue): T_imageDimensions;
  begin
    result.width:=inputResolution.height;
    result.height:=inputResolution.width;
    result:=context^.limitedDimensionsForResizeStep(result);
  end;

CONSTRUCTOR T_cropMeta.create;
begin
  inherited create(imc_geometry,
                   newParameterDescription(OP_NAME_CROP, pt_4floats)^
                     .addChildParameterDescription(spa_f0,'relative x0',pt_float)^
                     .addChildParameterDescription(spa_f1,'relative x1',pt_float)^
                     .addChildParameterDescription(spa_f2,'relative y0',pt_float)^
                     .addChildParameterDescription(spa_f3,'relative y1',pt_float)^
                     .setDefaultValue('0:1x0:1'),
                   @crop_impl,
                   sok_inputDependent)
end;

FUNCTION T_cropMeta.getOperationToCrop(CONST x0, x1, y0, y1: double
  ): P_simpleImageOperation;
  VAR value:T_parameterValue;
      op:P_simpleImageOperation;
  begin
    value.createFromValue(signature,x0,x1,y0,y1);
    new(op,create(@self,value));
    result:=op;
  end;

FUNCTION T_cropMeta.getExpectedOutputResolution(CONST context: P_abstractWorkflow; CONST inputResolution: T_imageDimensions; CONST parameters:T_parameterValue): T_imageDimensions;
  begin
    result:=context^.limitedDimensionsForResizeStep(crop(inputResolution,parameters.f0,parameters.f1,parameters.f2,parameters.f3));
  end;

FUNCTION registerResizeOperation(CONST name:string; CONST op: F_simpleImageOperation):P_simpleImageOperationMeta;
  VAR tmp:P_resizeMeta;
  begin
    new(tmp,create(name,op));
    registerOperation(tmp);
    result:=tmp;
  end;

FUNCTION registerRotateOperation(CONST name:string; CONST op: F_simpleImageOperation):P_simpleImageOperationMeta;
  VAR tmp:P_rotateMeta;
  begin
    new(tmp,create(name,op));
    registerOperation(tmp);
    result:=tmp;
  end;

INITIALIZATION
  pd_resize:=
  registerResizeOperation('resize',            @resize_impl       )^.getSimpleParameterDescription;
  registerResizeOperation('fit',               @fit_impl          );
  registerResizeOperation('fill',              @fill_impl         );
  registerResizeOperation('fitExpand',         @fitExpand_impl    );
  registerResizeOperation('fitRotate',         @fitRotate_impl    );
  registerResizeOperation('fillRotate',        @fillRotate_impl   );
  registerResizeOperation('resizePixelate',    @resizePxl_impl    );
  registerResizeOperation('fitPixelate',       @fitPxl_impl       );
  registerResizeOperation('fillPixelate',      @fillPxl_impl      );
  registerResizeOperation('fitExpandPixelate', @fitExpandPxl_impl );
  registerResizeOperation('fitRotatePixelate', @fitRotatePxl_impl );
  registerResizeOperation('fillRotatePixelate',@fillRotatePxl_impl);

  registerSimpleOperation(imc_geometry,
                          newParameterDescription('zoom', pt_float)^.setDefaultValue('0.5'),
                          @zoom_impl,
                          sok_inputDependent);
  registerSimpleOperation(imc_geometry,
                          newParameterDescription('flip', pt_none),
                          @flip_impl,
                          sok_inputDependent);
  registerSimpleOperation(imc_geometry,
                          newParameterDescription('flop', pt_none),
                          @flop_impl,
                          sok_inputDependent);
  registerRotateOperation('rotL', @rotL_impl);
  registerRotateOperation('rotR', @rotR_impl);
  registerSimpleOperation(imc_geometry,
                          newParameterDescription('rotate',pt_float,-3600,3600)^.setDefaultValue('45'),
                          @rotDegrees_impl,
                          sok_inputDependent);
  new(cropMeta,create);
  registerOperation(cropMeta);
end.

