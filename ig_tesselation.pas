UNIT ig_tesselation;
INTERFACE
USES myColors,
     myParams,
     complex,
     mypics,
     imageContexts,
     imageGeneration;

TYPE
  P_tilesAlgorithm=^T_tilesAlgorithm;
  T_tilesAlgorithm=object(T_scaledImageGenerationAlgorithm)
    geometryKind:byte;
    spiralParameter:longint;
    colorStyle:byte; //0: given color; 1:color by input
    BorderWidth,
    borderAngle: double;
    color:T_rgbFloatColor;

    CONSTRUCTOR create;
    PROCEDURE resetParameters(CONST style:longint); virtual;
    FUNCTION numberOfParameters:longint; virtual;
    PROCEDURE setParameter(CONST index:byte; CONST value:T_parameterValue); virtual;
    FUNCTION getParameter(CONST index:byte):T_parameterValue; virtual;
    PROCEDURE execute(CONST context:P_abstractWorkflow); virtual;
  end;

IMPLEMENTATION
USES ig_circlespirals,im_triangleSplit,math;

CONSTRUCTOR T_tilesAlgorithm.create;
  CONST geometryNames:array[0..9] of string=('squares',
                                             'triangles',
                                             'hexagons',
                                             'archimedic',
                                             'demiregular_a',
                                             'demiregular_b',
                                             'spiral_triangles',
                                             'spiral_hexagons',
                                             'double_spiral_triangles',
                                             'double_spiral_hexagons');
        colorSourceNames:array[0..1] of string=('fixed',
                                                'by_input');

  begin
    inherited create;
    addParameter('geometry',pt_enum,0,9)^.setEnumValues(geometryNames);
    addParameter('spiral_parameter',pt_integer,2,100);
    addParameter('coloring',pt_enum,0,1)^.setEnumValues(colorSourceNames);
    addParameter('color'   ,pt_color);
    addParameter('border_width',pt_float,0);
    addParameter('border_angle',pt_float,0,90);
    resetParameters(0);
  end;

PROCEDURE T_tilesAlgorithm.resetParameters(CONST style: longint);
  begin
    inherited resetParameters(style);
    spiralParameter:=20;
    geometryKind:=0;
    colorStyle:=0;
    BorderWidth:=1;
    borderAngle:=20;
    color:=WHITE*0.5;
  end;

FUNCTION T_tilesAlgorithm.numberOfParameters: longint;
  begin
    result:=inherited numberOfParameters+6;
  end;

PROCEDURE T_tilesAlgorithm.setParameter(CONST index: byte; CONST value: T_parameterValue);
  begin
    if index<inherited numberOfParameters then inherited setParameter(index,value)
    else case byte(index-inherited numberOfParameters) of
      0: geometryKind   :=value.i0;
      1: spiralParameter:=value.i0;
      2: colorStyle     :=value.i0;
      3: color          :=value.color;
      4: BorderWidth    :=value.f0;
      5: borderAngle    :=value.f0;
    end;
  end;

FUNCTION T_tilesAlgorithm.getParameter(CONST index: byte): T_parameterValue;
  begin
    if index<inherited numberOfParameters then exit(inherited getParameter(index));
    case byte(index-inherited numberOfParameters) of
      0: result.createFromValue(parameterDescription(inherited numberOfParameters+0),geometryKind   );
      1: result.createFromValue(parameterDescription(inherited numberOfParameters+1),spiralParameter);
      2: result.createFromValue(parameterDescription(inherited numberOfParameters+2),colorStyle     );
      3: result.createFromValue(parameterDescription(inherited numberOfParameters+3),color          );
      4: result.createFromValue(parameterDescription(inherited numberOfParameters+4),BorderWidth    );
      5: result.createFromValue(parameterDescription(inherited numberOfParameters+5),borderAngle    );
    end;
  end;

PROCEDURE T_tilesAlgorithm.execute(CONST context: P_abstractWorkflow);
  VAR tileBuilder:T_tileBuilder;
      scanColor:boolean;

  PROCEDURE createGeometry;
    CONST COS_60= 0.8660254037844387;
          GEOM_R=-0.6339745962155607;
          GEOM_Q=1.5+COS_60;

    VAR circleProvider:T_spiralCircleProvider;
        p0,p1,p2,p3,p4,p5:T_Complex;
        i0,i1,j0,j1,i,j:longint;
        world:T_boundingBox;
    begin
      world:=scaler.getWorldBoundingBox;
      case geometryKind of
        0: //'squares',
        begin
          i0:=floor(world.x0);
          i1:=ceil (world.x1);
          j0:=floor(world.y0);
          j1:=ceil (world.y1);
          for i:=i0 to i1 do for j:=j0 to j1 do
            tileBuilder.addQuad(scaler.mrofsnart(i  ,j),
                                scaler.mrofsnart(i  ,j+1),
                                scaler.mrofsnart(i+1,j+1),
                                scaler.mrofsnart(i+1,j  ),
                                color,scanColor);
        end;
        1: //'triangles',
        begin
          i0:=floor(world.x0/(2*COS_60))-1;
          i1:=ceil (world.x1/(2*COS_60));
          j0:=floor(world.y0*2/3);
          j1:=ceil (world.y1*2/3);
          for i:=i0 to i1 do for j:=j0 to j1 do begin
            tileBuilder.addTriangle(scaler.mrofsnart(COS_60*( 1+(j and 1)+i*2),0.5*( 1+j*3)),
                                    scaler.mrofsnart(COS_60*(   (j and 1)+i*2),0.5*(-2+j*3)),
                                    scaler.mrofsnart(COS_60*(-1+(j and 1)+i*2),0.5*( 1+j*3)),
                                    color,scanColor);
            tileBuilder.addTriangle(scaler.mrofsnart(COS_60*( 1+(j and 1)+i*2),0.5*( 1+j*3)),
                                    scaler.mrofsnart(COS_60*( 2+(j and 1)+i*2),0.5*(-2+j*3)),
                                    scaler.mrofsnart(COS_60*(   (j and 1)+i*2),0.5*(-2+j*3)),
                                    color,scanColor);
          end;
        end;
        2: //'hexagons',
        begin
          i0:=floor(world.x0/1.5)-1;
          i1:=ceil (world.x1/1.5);
          j0:=floor(world.y0/(2*COS_60));
          j1:=ceil (world.y1/(2*COS_60));
          for i:=i0 to i1 do for j:=j0 to j1 do begin
            p0.re:=1.5*i;
            p0.im:=2*COS_60*j+(i and 1)*COS_60;
            tileBuilder.addHexagon(scaler.mrofsnart(p0.re+0.5,p0.im-COS_60),
                                   scaler.mrofsnart(p0.re-0.5,p0.im-COS_60),
                                   scaler.mrofsnart(p0.re-1  ,p0.im       ),
                                   scaler.mrofsnart(p0.re-0.5,p0.im+COS_60),
                                   scaler.mrofsnart(p0.re+0.5,p0.im+COS_60),
                                   scaler.mrofsnart(p0.re+1  ,p0.im       ),
                                   color,scanColor);
          end;
        end;
        3: //'archimedic',
        begin
          i0:=floor(world.x0/(2*GEOM_Q))-1;
          i1:=ceil (world.x1/(2*GEOM_Q));
          j0:=floor(world.y0/GEOM_Q);
          j1:=ceil (world.y1/GEOM_Q);
          for i:=i0 to i1 do for j:=j0 to j1 do begin
            p0.re:=i*2*GEOM_Q+(j and 1)*GEOM_Q;
            p0.im:=j*GEOM_Q              ;
            tileBuilder.addQuad(
              scaler.mrofsnart(p0.re-GEOM_Q,p0.im+  GEOM_R),
              scaler.mrofsnart(p0.re-1.5   ,p0.im+  COS_60),
              scaler.mrofsnart(p0.re       ,p0.im         ),
              scaler.mrofsnart(p0.re-COS_60,p0.im+ -1.5   ),
              color,scanColor);
            tileBuilder.addQuad(
              scaler.mrofsnart(p0.re       ,p0.im       ),
              scaler.mrofsnart(p0.re+1.5   ,p0.im+COS_60),
              scaler.mrofsnart(p0.re+GEOM_Q,p0.im+GEOM_R),
              scaler.mrofsnart(p0.re+COS_60,p0.im-1.5   ),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re              ,p0.im    ),
              scaler.mrofsnart(p0.re+COS_60       ,p0.im-1.5),
              scaler.mrofsnart(p0.re-COS_60       ,p0.im-1.5),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re              ,p0.im         ),
              scaler.mrofsnart(p0.re              ,p0.im+2*COS_60),
              scaler.mrofsnart(p0.re+1.5          ,p0.im+  COS_60),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re              ,p0.im         ),
              scaler.mrofsnart(p0.re-1.5          ,p0.im+  COS_60),
              scaler.mrofsnart(p0.re              ,p0.im+2*COS_60),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re-GEOM_Q       ,p0.im+GEOM_R    ),
              scaler.mrofsnart(p0.re-GEOM_Q-COS_60,p0.im+GEOM_R+1.5),
              scaler.mrofsnart(p0.re-GEOM_Q+COS_60,p0.im+GEOM_R+1.5),
              color,scanColor);
          end;
        end;
        4: //'demiregular_a',
        begin
          i0:=floor(world.x0/(COS_60+1.5))-1;
          i1:=ceil (world.x1/(COS_60+1.5));
          j0:=floor(world.y0/(1+2*COS_60));
          j1:=ceil (world.y1/(1+2*COS_60));
          for i:=i0 to i1 do for j:=j0 to j1 do begin
            p0.re:=(1+COS_60)*(2*i+(j and 1));
            p0.im:=(1.5+2*COS_60)*j;
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re+1  ,p0.im       ),
              scaler.mrofsnart(p0.re    ,p0.im       ),
              scaler.mrofsnart(p0.re+0.5,p0.im+COS_60),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re+ 0.5,p0.im+COS_60),
              scaler.mrofsnart(p0.re+ 0  ,p0.im       ),
              scaler.mrofsnart(p0.re+-0.5,p0.im+COS_60),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re-0.5,p0.im+COS_60),
              scaler.mrofsnart(p0.re    ,p0.im       ),
              scaler.mrofsnart(p0.re-1  ,p0.im       ),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re-1  ,p0.im       ),
              scaler.mrofsnart(p0.re    ,p0.im       ),
              scaler.mrofsnart(p0.re-0.5,p0.im-COS_60),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re-0.5,p0.im-COS_60),
              scaler.mrofsnart(p0.re    ,p0.im       ),
              scaler.mrofsnart(p0.re+0.5,p0.im-COS_60),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re+ 0.5,p0.im+-COS_60),
              scaler.mrofsnart(p0.re+ 0  ,p0.im),
              scaler.mrofsnart(p0.re+ 1  ,p0.im),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re+ 0.5       ,p0.im+COS_60+1),
              scaler.mrofsnart(p0.re+-0.5       ,p0.im+COS_60+1),
              scaler.mrofsnart(p0.re+  0        ,p0.im+2*COS_60+1),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re+-0.5       ,p0.im+COS_60+1  ),
              scaler.mrofsnart(p0.re+-0.5       ,p0.im+COS_60    ),
              scaler.mrofsnart(p0.re+-0.5-COS_60,p0.im+COS_60+0.5),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re+ 0.5       ,p0.im+-COS_60-1  ),
              scaler.mrofsnart(p0.re+ 0.5       ,p0.im+-COS_60    ),
              scaler.mrofsnart(p0.re+ 0.5+COS_60,p0.im+-COS_60-0.5),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re+ 0.5+COS_60,p0.im+COS_60+0.5),
              scaler.mrofsnart(p0.re+ 0.5       ,p0.im+COS_60    ),
              scaler.mrofsnart(p0.re+ 0.5       ,p0.im+COS_60+1  ),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re+-0.5-COS_60,p0.im+-COS_60-0.5),
              scaler.mrofsnart(p0.re+-0.5       ,p0.im+-COS_60    ),
              scaler.mrofsnart(p0.re+-0.5       ,p0.im+-COS_60-1  ),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re+1+COS_60,p0.im+-0.5),
              scaler.mrofsnart(p0.re+1       ,p0.im     ),
              scaler.mrofsnart(p0.re+1+COS_60,p0.im+ 0.5),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re+-1-COS_60,p0.im+ 0.5),
              scaler.mrofsnart(p0.re+-1       ,p0.im     ),
              scaler.mrofsnart(p0.re+-1-COS_60,p0.im+-0.5),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re+1.5+COS_60,p0.im+0.5+COS_60),
              scaler.mrofsnart(p0.re+1  +COS_60,p0.im+0.5       ),
              scaler.mrofsnart(p0.re+0.5+COS_60,p0.im+0.5+COS_60),
              color,scanColor);
            tileBuilder.addQuad(
              scaler.mrofsnart(p0.re+-0.5,p0.im+COS_60  ),
              scaler.mrofsnart(p0.re+-0.5,p0.im+COS_60+1),
              scaler.mrofsnart(p0.re+ 0.5,p0.im+COS_60+1),
              scaler.mrofsnart(p0.re+ 0.5,p0.im+COS_60  ),
              color,scanColor);
            tileBuilder.addQuad(
              scaler.mrofsnart(p0.re+-0.5,p0.im+-COS_60-1),
              scaler.mrofsnart(p0.re+-0.5,p0.im+-COS_60  ),
              scaler.mrofsnart(p0.re+ 0.5,p0.im+-COS_60  ),
              scaler.mrofsnart(p0.re+ 0.5,p0.im+-COS_60-1),
              color,scanColor);
            tileBuilder.addQuad(
              scaler.mrofsnart(p0.re+0.5+COS_60,p0.im+0.5+COS_60),
              scaler.mrofsnart(p0.re+1  +COS_60,p0.im+0.5       ),
              scaler.mrofsnart(p0.re+1         ,p0.im+0         ),
              scaler.mrofsnart(p0.re+0.5       ,p0.im+    COS_60),
              color,scanColor);
            tileBuilder.addQuad(
              scaler.mrofsnart(p0.re+-0.5-COS_60,p0.im+-0.5-COS_60),
              scaler.mrofsnart(p0.re+-1  -COS_60,p0.im+-0.5       ),
              scaler.mrofsnart(p0.re+-1         ,p0.im+ 0         ),
              scaler.mrofsnart(p0.re+-0.5       ,p0.im+    -COS_60),
              color,scanColor);
            tileBuilder.addQuad(
              scaler.mrofsnart(p0.re+-1  -COS_60,p0.im+0.5       ),
              scaler.mrofsnart(p0.re+-0.5-COS_60,p0.im+0.5+COS_60),
              scaler.mrofsnart(p0.re+-0.5       ,p0.im+    COS_60),
              scaler.mrofsnart(p0.re+-1         ,p0.im+0         ),
              color,scanColor);
            tileBuilder.addQuad(
              scaler.mrofsnart(p0.re+1  +COS_60,p0.im+-0.5       ),
              scaler.mrofsnart(p0.re+0.5+COS_60,p0.im+-0.5-COS_60),
              scaler.mrofsnart(p0.re+0.5       ,p0.im+    -COS_60),
              scaler.mrofsnart(p0.re+1         ,p0.im+ 0         ),
              color,scanColor);
          end;
        end;
        5: //'demiregular_b',
        begin
          i0:=floor(world.x0/(COS_60+1.5));
          i1:=ceil (world.x1/(COS_60+1.5));
          j0:=floor(world.y0/(1+2*COS_60))-1;
          j1:=ceil (world.y1/(1+2*COS_60));
          for i:=i0 to i1 do for j:=j0 to j1 do begin
            p0.re:=(COS_60+1.5)*i;
            p0.im:=(1+2*COS_60)*j+(i and 1)*(COS_60+0.5);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re+1  ,p0.im+0     ),
              scaler.mrofsnart(p0.re+0  ,p0.im+0     ),
              scaler.mrofsnart(p0.re+0.5,p0.im+COS_60),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re+ 0.5,p0.im+COS_60),
              scaler.mrofsnart(p0.re+ 0  ,p0.im+0     ),
              scaler.mrofsnart(p0.re+-0.5,p0.im+COS_60),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re+-0.5,p0.im+COS_60),
              scaler.mrofsnart(p0.re+0   ,p0.im+0     ),
              scaler.mrofsnart(p0.re+-1  ,p0.im+0     ),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re+-1  ,p0.im+0      ),
              scaler.mrofsnart(p0.re+0   ,p0.im+0      ),
              scaler.mrofsnart(p0.re+-0.5,p0.im+-COS_60),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re+-0.5,p0.im+-COS_60),
              scaler.mrofsnart(p0.re+0   ,p0.im+0      ),
              scaler.mrofsnart(p0.re+ 0.5,p0.im+-COS_60),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re+ 0.5,p0.im+-COS_60),
              scaler.mrofsnart(p0.re+0   ,p0.im+0      ),
              scaler.mrofsnart(p0.re+ 1  ,p0.im+0      ),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re+-0.5       ,p0.im+COS_60+1  ),
              scaler.mrofsnart(p0.re+-0.5       ,p0.im+COS_60    ),
              scaler.mrofsnart(p0.re+-0.5-COS_60,p0.im+COS_60+0.5),
              color,scanColor);
            tileBuilder.addTriangle(
              scaler.mrofsnart(p0.re+ 0.5+COS_60,p0.im+COS_60+0.5),
              scaler.mrofsnart(p0.re+ 0.5       ,p0.im+COS_60    ),
              scaler.mrofsnart(p0.re+ 0.5       ,p0.im+COS_60+1  ),
              color,scanColor);
            tileBuilder.addQuad(
              scaler.mrofsnart(p0.re+-0.5,p0.im+COS_60  ),
              scaler.mrofsnart(p0.re+-0.5,p0.im+COS_60+1),
              scaler.mrofsnart(p0.re+ 0.5,p0.im+COS_60+1),
              scaler.mrofsnart(p0.re+ 0.5,p0.im+COS_60  ),
              color,scanColor);
            tileBuilder.addQuad(
              scaler.mrofsnart(p0.re+0.5+COS_60,p0.im+0.5+COS_60),
              scaler.mrofsnart(p0.re+1  +COS_60,p0.im+0.5       ),
              scaler.mrofsnart(p0.re+1         ,p0.im+0         ),
              scaler.mrofsnart(p0.re+0.5       ,p0.im+    COS_60),
              color,scanColor);
            tileBuilder.addQuad(
              scaler.mrofsnart(p0.re+-1  -COS_60,p0.im+0.5       ),
              scaler.mrofsnart(p0.re+-0.5-COS_60,p0.im+0.5+COS_60),
              scaler.mrofsnart(p0.re+-0.5       ,p0.im+    COS_60),
              scaler.mrofsnart(p0.re+-1         ,p0.im+0         ),
              color,scanColor);
          end;
        end;
        6..9: //spiral_triangles, spiral_hexagons, double_spiral_triangles, double_spiral_hexagons
        begin
          {$ifdef debugMode} writeln('Initializing spiral tiling with parameter ',geometryKind,'/',spiralParameter); {$endif}
          if geometryKind in [6,7]
          then circleProvider.create(spiralParameter,1, 0,0,1)
          else circleProvider.create(spiralParameter,1,-1,1,1);
          if geometryKind in [6,8] then for i:=-10000 to 10000 do begin
            if circleProvider.getQuad(i,scaler,p0,p1,p2,p3)
            then begin
              tileBuilder.addTriangle(p0,p2,p1,color,scanColor);
              tileBuilder.addTriangle(p0,p3,p2,color,scanColor);
            end;
          end else for i:=-10000 to 10000 do begin
            if circleProvider.getHexagon(i,scaler,p0,p1,p2,p3,p4,p5)
            then tileBuilder.addHexagon(p0,p1,p2,p3,p4,p5,color,scanColor);
          end;
          circleProvider.destroy;
        end;
      end;

    end;

  begin with context^ do begin
    scaler.rescale(image.dimensions.width,image.dimensions.height);
    tileBuilder.create(context,BorderWidth,borderAngle);
    scanColor:=colorStyle=1;

    createGeometry;
    tileBuilder.execute;
    tileBuilder.destroy;
  end; end;

FUNCTION newTilesAlgorithm:P_generalImageGenrationAlgorithm;
  begin
    new(P_tilesAlgorithm(result),create);
  end;

INITIALIZATION
  registerAlgorithm('Tiles',@newTilesAlgorithm,true,false,false);

end.
