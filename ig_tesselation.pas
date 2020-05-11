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
    moebiusA,moebiusB,moebiusC,moebiusD:T_Complex;

    CONSTRUCTOR create;
    PROCEDURE resetParameters(CONST style:longint); virtual;
    FUNCTION numberOfParameters:longint; virtual;
    PROCEDURE setParameter(CONST index:byte; CONST value:T_parameterValue); virtual;
    FUNCTION getParameter(CONST index:byte):T_parameterValue; virtual;
    PROCEDURE execute(CONST context:P_abstractWorkflow); virtual;
  end;

IMPLEMENTATION
USES ig_circlespirals,im_triangleSplit,math,sysutils;

CONSTRUCTOR T_tilesAlgorithm.create;
  CONST geometryNames:array[0..10] of string=({ 0} 'squares',
                                              { 1} 'triangles',
                                              { 2} 'hexagons',
                                              { 3} 'archimedic',
                                              { 4} 'demiregular_a',
                                              { 5} 'demiregular_b',
                                              { 6} 'spiral_triangles',
                                              { 7} 'spiral_hexagons',
                                              { 8} 'sunflower',
                                              { 9} 'fishbone',
                                              {10} 'Conway');
        colorSourceNames:array[0..1] of string=('fixed',
                                                'by_input');

  begin
    inherited create;
    addParameter('geometry',pt_enum,0,12)^.setEnumValues(geometryNames);
    addParameter('coloring',pt_enum,0,1)^.setEnumValues(colorSourceNames);
    addParameter('color'   ,pt_color);
    addParameter('border_width',pt_float,0);
    addParameter('border_angle',pt_float,0,90);
    addParameter('spiral_parameter',pt_integer,2,100);
    addParameter('mt_a',pt_2floats);
    addParameter('mt_b',pt_2floats);
    addParameter('mt_c',pt_2floats);
    addParameter('mt_d',pt_2floats);
    resetParameters(0);
  end;

PROCEDURE T_tilesAlgorithm.resetParameters(CONST style: longint);
  begin
    inherited resetParameters(style);
    geometryKind:=0;
    colorStyle:=0;
    BorderWidth:=1;
    borderAngle:=20;
    color:=WHITE*0.5;
    spiralParameter:=20;
    moebiusA:=1;
    moebiusB:=0;
    moebiusC:=0;
    moebiusD:=1;
  end;

FUNCTION T_tilesAlgorithm.numberOfParameters: longint;
  begin
    result:=inherited numberOfParameters+10;
  end;

PROCEDURE T_tilesAlgorithm.setParameter(CONST index: byte; CONST value: T_parameterValue);
  begin
    if index<inherited numberOfParameters then inherited setParameter(index,value)
    else case byte(index-inherited numberOfParameters) of
      0: geometryKind   :=value.i0;
      1: colorStyle     :=value.i0;
      2: color          :=value.color;
      3: BorderWidth    :=value.f0;
      4: borderAngle    :=value.f0;
      5: spiralParameter:=value.i0;
      6: moebiusA:=value.f0+II*value.f1;
      7: moebiusB:=value.f0+II*value.f1;
      8: moebiusC:=value.f0+II*value.f1;
      9: moebiusD:=value.f0+II*value.f1;
    end;
  end;

FUNCTION T_tilesAlgorithm.getParameter(CONST index: byte): T_parameterValue;
  begin
    if index<inherited numberOfParameters then exit(inherited getParameter(index));
    case byte(index-inherited numberOfParameters) of
      0: result.createFromValue(parameterDescription(inherited numberOfParameters+0),geometryKind   );
      1: result.createFromValue(parameterDescription(inherited numberOfParameters+1),colorStyle     );
      2: result.createFromValue(parameterDescription(inherited numberOfParameters+2),color          );
      3: result.createFromValue(parameterDescription(inherited numberOfParameters+3),BorderWidth    );
      4: result.createFromValue(parameterDescription(inherited numberOfParameters+4),borderAngle    );
      5: result.createFromValue(parameterDescription(inherited numberOfParameters+5),spiralParameter);
      6: result.createFromValue(parameterDescription(inherited numberOfParameters+6),moebiusA.re,moebiusA.im);
      7: result.createFromValue(parameterDescription(inherited numberOfParameters+7),moebiusB.re,moebiusB.im);
      8: result.createFromValue(parameterDescription(inherited numberOfParameters+8),moebiusC.re,moebiusC.im);
      9: result.createFromValue(parameterDescription(inherited numberOfParameters+9),moebiusD.re,moebiusD.im);
    end;
  end;

PROCEDURE T_tilesAlgorithm.execute(CONST context: P_abstractWorkflow);
  VAR tileBuilder:T_tileBuilder;
      scanColor:boolean;

  PROCEDURE initSunflowerGeometry;
    FUNCTION fibPoint(CONST i:longint):T_Complex;
      CONST gamma=2*pi/system.sqr((system.sqrt(5)-1)/2);
      begin
        result.re:=system.cos(gamma*i);
        result.im:=system.sin(gamma*i);
        result*=system.sqrt(i);
        result:=scaler.mrofsnart(result.re,result.im);
      end;

    PROCEDURE addFibTriangle(CONST i0,i1,i2:longint); inline;
      begin tileBuilder.addTriangle(fibPoint(i0),fibPoint(i1),fibPoint(i2),color,scanColor); end;

    PROCEDURE addFibQuad(CONST i0,i1,i2,i3:longint); inline;
      begin tileBuilder.addQuad(fibPoint(i0),fibPoint(i1),fibPoint(i2),fibPoint(i3),color,scanColor); end;

    FUNCTION maxSqrRadius:longint;
      VAR box:T_boundingBox;
          f:double;
      begin
        box:=scaler.getWorldBoundingBox;
        f:=max(box.x0*box.x0,box.x1*box.x1)+
           max(box.y0*box.y0,box.y1*box.y1);
        if      f<17.0      then result:=17
        else if (f>5000000.0) or isNan(f) or isInfinite(f) then result:=5000000
        else result:=ceil(f);
      end;

    VAR i,imax:longint;
    begin
      imax:=maxSqrRadius;
      addFibTriangle(1, 2, 3);
      addFibTriangle(1, 4, 2);
      addFibTriangle(2,10, 5);
      addFibTriangle(5,13, 8);
      addFibTriangle(1, 9, 4);
      addFibQuad(2, 4,12,7);
      addFibQuad(2, 5, 8,3);
      addFibQuad(1, 3,11,6);
      addFibQuad(1, 6,14,9);
      context^.messageQueue^.Post('iMax='+intToStr(imax),false,context^.currentStepIndex,context^.stepCount);
      for i:=     1+1 to      1+   8 do addFibTriangle(i,i+   5,i+  13);
      for i:=     1+1 to     18      do addFibQuad    (i,i+  13,i+  21,i+   8);
      if imax<   18 then exit;
      for i:=    18+1 to     18+  13 do addFibTriangle(i,i+  21,i+   8);
      for i:=    18+1 to     67      do addFibQuad    (i,i+  13,i+  34,i+  21);
      if imax<   67 then exit;
      for i:=    67+1 to     67+  21 do addFibTriangle(i,i+  13,i+  34);
      for i:=    67+1 to    187      do addFibQuad    (i,i+  34,i+  55,i+  21);
      if imax<  187 then exit;
      for i:=   187+1 to    187+  34 do addFibTriangle(i,i+  55,i+  21);
      for i:=   187+1 to    508      do addFibQuad    (i,i+  34,i+  89,i+  55);
      if imax<  508 then exit;
      for i:=   508+1 to    508+  55 do addFibTriangle(i,i+  34,i+  89);
      for i:=   508+1 to   1360      do addFibQuad    (i,i+  89,i+ 144,i+  55);
      if imax< 1360 then exit;
      for i:=  1360+1 to   1360+  89 do addFibTriangle(i,i+ 144,i+  55);
      for i:=  1360+1 to   3610      do addFibQuad    (i,i+  89,i+ 233,i+ 144);
      if imax< 3610 then exit;
      for i:=  3610+1 to   3610+ 144 do addFibTriangle(i,i+  89,i+ 233);
      for i:=  3610+1 to   9530      do addFibQuad    (i,i+ 233,i+ 377,i+ 144);
      if imax< 9530 then exit;
      for i:=  9530+1 to   9530+ 233 do addFibTriangle(i,i+ 377,i+ 144);
      for i:=  9530+1 to  25080      do addFibQuad    (i,i+ 233,i+ 610,i+ 377);
      if imax<25080 then exit;
      for i:= 25080+1 to  25080+ 377 do addFibTriangle(i,i+ 233,i+ 610);
      for i:= 25080+1 to  65871      do addFibQuad    (i,i+ 610,i+ 987,i+ 377);
      if imax<65871 then exit;
      for i:= 65871+1 to  65871+ 610 do addFibTriangle(i,i+ 987,i+ 377);
      for i:= 65871+1 to 172793      do addFibQuad    (i,i+ 610,i+1597,i+ 987);
      if imax<172793 then exit;
      for i:=172793+1 to 172793+ 987 do addFibTriangle(i,i+ 610,i+1597);
      for i:=172793+1 to 452929      do addFibQuad    (i,i+1597,i+2584,i+ 987);
      if imax<452929 then exit;
      for i:=452929+1 to 452929+1597 do addFibTriangle(i,i+2584,i+ 987);
      for i:=452929+1 to 997415      do addFibQuad    (i,i+1597,i+4181,i+2584);
      if imax<997415 then exit;
      for i:=997415+1 to 997415+2584 do addFibTriangle(i,i+1597,i+4181);
      for i:=997415+1 to imax        do addFibQuad    (i,i+4181,i+6765,i+2584);
    end;

  PROCEDURE initConwayGeometry;
    VAR worldBox:T_boundingBox;
    PROCEDURE recurse(CONST a,b,c:T_Complex; CONST depth:byte);
      VAR x,y:T_Complex;
      begin
        if depth=0 then begin
          if crossProduct(a,b,c.re,c.im)<0
          then begin x:=b; y:=c; end
          else begin x:=c; y:=b; end;
          tileBuilder.addTriangle(scaler.mrofsnart(a.re,a.im),
                                  scaler.mrofsnart(x.re,x.im),
                                  scaler.mrofsnart(y.re,y.im),
                                  color,scanColor);
        end else if (max(a.re,max(b.re,c.re))>=worldBox.x0) and
                    (min(a.re,min(b.re,c.re))<=worldBox.x1) and
                    (max(a.im,max(b.im,c.im))>=worldBox.y0) and
                    (min(a.im,min(b.im,c.im))<=worldBox.y1) then begin
          x:=(b-a)*0.5;
          y:= c-a;
          recurse(a+2/5*x+4/5*y, a            , a+y          ,depth-1);
          recurse(a+1/5*x+2/5*y, a+  x        , a            ,depth-1);
          recurse(a+6/5*x+2/5*y, a+2*x        , a+x          ,depth-1);
          recurse(a+1/5*x+2/5*y, a+x          , a+2/5*x+4/5*y,depth-1);
          recurse(a+6/5*x+2/5*y, a+2/5*x+4/5*y, a+x          ,depth-1);
        end;
      end;

    begin
      worldBox:=scaler.getWorldBoundingBox;
      recurse((-1-II*0.5)*100,( 1-II*0.5)*100,(-1+II*0.5)*100,8);
      recurse(( 1+II*0.5)*100,(-1+II*0.5)*100,( 1-II*0.5)*100,8);
    end;

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
        6..7: //spiral_triangles, spiral_hexagons
        begin
          circleProvider.create(spiralParameter,moebiusA,moebiusB,moebiusC,moebiusD);
          if geometryKind=6 then for i:=-10000 to 10000 do begin
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
        8:initSunflowerGeometry;
        9:begin
          i0:=floor(world.x0/8)-1;
          i1:=ceil (world.x1/8);
          j0:=floor(world.y0/2)-2;
          j1:=ceil (world.y1/2);
          for i:=i0 to i1 do for j:=j0 to j1 do begin
            p0.re:=i*8;
            p0.im:=j*2;
            tileBuilder.addQuad(scaler.mrofsnart(p0.re  ,p0.im  ),
                                scaler.mrofsnart(p0.re+4,p0.im+4),
                                scaler.mrofsnart(p0.re+5,p0.im+3),
                                scaler.mrofsnart(p0.re+1,p0.im-1),
                                color,scanColor);
            tileBuilder.addQuad(scaler.mrofsnart(p0.re-4,p0.im+4),
                                scaler.mrofsnart(p0.re-3,p0.im+5),
                                scaler.mrofsnart(p0.re+1,p0.im+1),
                                scaler.mrofsnart(p0.re  ,p0.im  ),
                                color,scanColor);
          end;
        end;
        10: initConwayGeometry;
      end;

    end;

  begin with context^ do begin
    scaler.rescale(image.dimensions.width,image.dimensions.height);
    tileBuilder.create(context,BorderWidth,borderAngle);
    scanColor:=colorStyle=1;
    createGeometry;
    tileBuilder.execute(not(scanColor),color);
    tileBuilder.destroy;
  end; end;

FUNCTION newTilesAlgorithm:P_generalImageGenrationAlgorithm;
  begin
    new(P_tilesAlgorithm(result),create);
  end;

INITIALIZATION
  registerAlgorithm('Tiles',@newTilesAlgorithm,true,false,false);

end.

