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
USES mypics,sysutils,myColors,darts;
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

PROCEDURE resize_impl       (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_exact,not context^.previewQuality); end;
PROCEDURE fit_impl          (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_fit,not context^.previewQuality); end;
PROCEDURE fill_impl         (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_cropToFill,not context^.previewQuality); end;
PROCEDURE fitExpand_impl    (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_fitExpand,not context^.previewQuality); end;
PROCEDURE fitRotate_impl    (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_fitRotate,not context^.previewQuality); end;
PROCEDURE fillRotate_impl   (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_cropRotate,not context^.previewQuality); end;
PROCEDURE resizePxl_impl    (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_exactPixelate,not context^.previewQuality); end;
PROCEDURE fitPxl_impl       (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_fitPixelate,not context^.previewQuality); end;
PROCEDURE fillPxl_impl      (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_cropToFillPixelate,not context^.previewQuality); end;
PROCEDURE fitExpandPxl_impl (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_fitExpandPixelate,not context^.previewQuality); end;
PROCEDURE fitRotatePxl_impl (CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_fitRotatePixelate,not context^.previewQuality); end;
PROCEDURE fillRotatePxl_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow); begin context^.image.resize(targetDimensions(parameters,context),res_cropRotatePixelate,not context^.previewQuality); end;
PROCEDURE crop_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  begin
    context^.image.crop(parameters.f0,parameters.f1,parameters.f2,parameters.f3);
  end;

PROCEDURE zoom_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  begin context^.image.zoom(parameters.f0,not(context^.previewQuality)); end;

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
  begin context^.image.rotate(parameters.f0,not(context^.previewQuality)); end;

PROCEDURE keystone_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  VAR py:double;
      temp:T_rawImage;
      cx,newCx,scaling:double;

  FUNCTION transformedPixel(CONST x,y:double):T_rgbFloatColor;
    VAR worldX,worldY:double;
        k:longint;
        points:T_pointList;
    begin
      if context^.previewQuality then begin
        worldY:=y/(1-py*y);
        worldX:=(x-newCx)*(1+py*worldY)+cx;
        result:=temp.simpleSubPixel(worldX,worldY);
      end else begin
        result:=BLACK;
        points.clear;
        for k:=0 to 31 do begin
          worldY:=y+darts_delta[k,1];
          worldY:=worldY/(1-py*worldY);
          worldX:=(x+darts_delta[k,0]-newCx)*(1+py*worldY)+cx;
          points.add(worldX,worldY);
        end;
        result:=temp.subPixelAverage(points);
      end;
    end;

  VAR x,y:longint;
      newY1,newX0,newX1:double;
      newDim,limitedNewDim:T_imageDimensions;
  begin
    temp.create(context^.image);
    py:=parameters.f0/temp.dimensions.height;
    if parameters.f0>0 then begin
      temp.flip;
      py:=-py;
    end;
    newY1:=(temp.dimensions.height-1) /(1+py*(temp.dimensions.height-1));
    newX1:=(temp.dimensions.width-1)/2/(1+py*(temp.dimensions.height-1));
    newX0:=-newX1;

    newDim:=imageDimensions(round(newX1-newX0+1),round(newY1+1));
    limitedNewDim:=context^.limitedDimensionsForResizeStep(newDim);
    context^.image.resize(limitedNewDim,res_dataResize,false);
    scaling:=newDim.height/limitedNewDim.height;

    cx:=temp.dimensions.width /2;
    newCx:=newDim.width/2;
    for y:=0 to limitedNewDim.height-1 do
    for x:=0 to limitedNewDim.width-1 do
      context^.image.pixel[x,y]:=transformedPixel(x*scaling,y*scaling);
    temp.destroy;
    if parameters.f0>0 then context^.image.flip;

  end;

PROCEDURE bestMatchingGradient_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  VAR x0,x1,y0,y1,x,y:longint;
      scale,rx,ry:double;

      sumC   :T_rgbFloatColor=(0,0,0);
      sumXC  :T_rgbFloatColor=(0,0,0);
      sumYC  :T_rgbFloatColor=(0,0,0);
      sumXYC :T_rgbFloatColor=(0,0,0);
      sumX   :double=0;
      sumY   :double=0;
      sumXY  :double=0;
      sumXX  :double=0;
      sumXXY :double=0;
      sumYY  :double=0;
      sumXYY :double=0;
      sumXXYY:double=0;
      col: T_rgbFloatColor;
      normalizationFactor:double;

      mat:array[0..3,0..7] of double;

  begin
    x0:=round(parameters.f0*(context^.image.dimensions.width -1)); if x0<0 then x0:=0 else if x0>=context^.image.dimensions.width  then x0:=context^.image.dimensions.width -1;
    x1:=round(parameters.f1*(context^.image.dimensions.width -1)); if x1<0 then x1:=0 else if x1>=context^.image.dimensions.width  then x1:=context^.image.dimensions.width -1;
    y0:=round(parameters.f2*(context^.image.dimensions.height-1)); if y0<0 then y0:=0 else if y0>=context^.image.dimensions.height then y0:=context^.image.dimensions.height-1;
    y1:=round(parameters.f3*(context^.image.dimensions.height-1)); if y1<0 then y1:=0 else if y1>=context^.image.dimensions.height then y1:=context^.image.dimensions.height-1;
    if x0>x1 then begin x:=x0; x0:=x1; x1:=x; end;
    if y0>y1 then begin y:=y0; y0:=y1; y1:=y; end;
    scale:=1/context^.image.diagonal;

    normalizationFactor:=1/(y1-y0+1)/(x1-x0+1);
    for y:=y0 to y1 do
    for x:=x0 to x1 do begin
      rx:=x*scale;
      ry:=y*scale;
      col:=context^.image.pixel[x,y];
      sumC   +=col*       normalizationFactor ;
      sumXC  +=col*(rx   *normalizationFactor);
      sumYC  +=col*(ry   *normalizationFactor);
      sumXYC +=col*(rx*ry*normalizationFactor);
      sumX   +=rx         *normalizationFactor;
      sumY   +=      ry   *normalizationFactor;
      sumXY  +=rx   *ry   *normalizationFactor;
      sumXX  +=rx*rx      *normalizationFactor;
      sumXXY +=rx*rx*ry   *normalizationFactor;
      sumYY  +=      ry*ry*normalizationFactor;
      sumXYY +=rx   *ry*ry*normalizationFactor;
      sumXXYY+=rx*rx*ry*ry*normalizationFactor;
    end;

    mat[0,0]:=1;     mat[0,1]:=sumX;   mat[0,2]:=sumY;   mat[0,3]:=sumXY;   mat[0,4]:=1; mat[0,5]:=0; mat[0,6]:=0; mat[0,7]:=0;
    mat[1,0]:=sumX;  mat[1,1]:=sumXX;  mat[1,2]:=sumXY;  mat[1,3]:=sumXXY;  mat[1,4]:=0; mat[1,5]:=1; mat[1,6]:=0; mat[1,7]:=0;
    mat[2,0]:=sumY;  mat[2,1]:=sumXY;  mat[2,2]:=sumYY;  mat[2,3]:=sumXYY;  mat[2,4]:=0; mat[2,5]:=0; mat[2,6]:=1; mat[2,7]:=0;
    mat[3,0]:=sumXY; mat[3,1]:=sumXXY; mat[3,2]:=sumXYY; mat[3,3]:=sumXXYY; mat[3,4]:=0; mat[3,5]:=0; mat[3,6]:=0; mat[3,7]:=1;

    for x:=0 to 3 do begin
      //divide by diagonal element
      normalizationFactor:=1/mat[x,x];
      mat[x,x]:=1;
      for y:=x+1 to 7 do mat[x,y]*=normalizationFactor;

      //subtract from all other lines
      for x0:=0 to 3 do if x0<>x then begin
        normalizationFactor:=mat[x0,x];
        for y:=x to 7 do mat[x0,y]-=mat[x,y]*normalizationFactor;
      end;
    end;

  end;

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
  registerSimpleOperation(imc_geometry,
                          newParameterDescription('keystone',pt_float)^.setDefaultValue('0.2'),
                          @keystone_impl,
                          sok_inputDependent);
  new(cropMeta,create);
  registerOperation(cropMeta);
end.

