UNIT im_misc;
INTERFACE
IMPLEMENTATION
USES imageManipulation,imageContexts,myParams,mypics,myColors,math,pixMaps;

PROCEDURE sketch_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  begin
    context^.image.sketch(parameters.f0,parameters.f1,parameters.f2,parameters.f3);
  end;

PROCEDURE drip_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  begin
    context^.image.drip(parameters.f0,parameters.f1);
  end;

PROCEDURE encircle(VAR image:T_rawImage; CONST count:longint; CONST background:T_rgbFloatColor; CONST opacity,relativeCircleSize:double; CONST context:P_abstractWorkflow);
  TYPE T_circle=record
         cx,cy,radius,diff:double;
         color:T_rgbFloatColor;
       end;

  FUNCTION randomCircle(CONST radius:double):T_circle;
    begin
      result.cx:=radius+random*(image.dimensions.width-2*radius);
      result.cy:=radius+random*(image.dimensions.height-2*radius);
      result.radius:=radius;
      result.diff:=0;
    end;

  FUNCTION avgColor(VAR source:T_rawImage; CONST circle:T_circle):T_rgbFloatColor;
    VAR sampleCount:longint=0;
        sqrRad:double;
        x,y:longint;
    begin
      sqrRad:=sqr(circle.radius);
      result:=BLACK;
      with circle do
      for y:=max(0,round(cy-radius)) to min(image.dimensions.height-1,round(cy+radius)) do
      for x:=max(0,round(cx-radius)) to min(image.dimensions.width-1,round(cx+radius)) do
      if sqr(x-cx)+sqr(y-cy)<=sqrRad then
      begin
        result:=result+source[x,y];
        inc(sampleCount);
      end;
      if sampleCount>0 then result:=result*(1/sampleCount);
    end;

  VAR copy:T_rawImage;
      i,j:longint;
      newCircle,toDraw: T_circle;

  FUNCTION globalAvgDiff:double;
    VAR i:longint;
    begin
      result:=0;
      for i:=0 to image.pixelCount-1 do result:=result+colDiff(copy.rawData[i],image.rawData[i]);
      result/=image.pixelCount;
    end;

  PROCEDURE drawCircle(CONST circle:T_circle);
    VAR sqrRad:double;
        x,y,k:longint;
        r:double;
    begin
      sqrRad:=sqr(circle.radius+1);
      with circle do
      for y:=max(0,floor(cy-radius)) to min(image.dimensions.height-1,ceil(cy+radius)) do
      for x:=max(0,floor(cx-radius)) to min(image.dimensions.width-1,ceil(cx+radius)) do begin
        r:=sqr(x-cx)+sqr(y-cy);
        if r<=sqrRad then
        begin
          k:=x+y*image.dimensions.width;
          r:=sqrt(r);
          if r<radius-0.5 then r:=opacity
          else if r>radius+0.5 then r:=0
          else r:=(radius+0.5-r)*opacity;
          if r>0 then image.rawData[k]:=image.rawData[k]*(1-r)+color*r;
        end;

      end;
    end;

  FUNCTION bestCircle(CONST radius:double):T_circle;
    VAR x,y,cx,cy:longint;
        diff:double;
        maxDiff:double=0;
    begin
      if (radius>0.5*min(image.dimensions.width,image.dimensions.height)) then exit(bestCircle(0.499*min(image.dimensions.width,image.dimensions.height)));
      for y:=round(radius) to round(image.dimensions.height-radius) do
      for x:=round(radius) to round(image.dimensions.width-radius) do begin
        diff:=colDiff(image.pixel[x,y],copy[x,y]);
        if (diff>maxDiff) then begin
          cx:=x;
          cy:=y;
          maxDiff:=diff;
        end;
      end;
      result.cx:=cx;
      result.cy:=cy;
      result.radius:=radius;
      result.diff:=diff;
      result.color:=avgColor(copy,result);
    end;

  VAR radius:double;
      circleSamples:longint=1;
  begin
    radius:=relativeCircleSize*image.diagonal;
    copy.create(image);
    image.clearWithColor(background);
    for i:=0 to count-1 do begin
      if ((i*1000) div count<>((i-1)*1000) div count) or (radius>=0.1*image.diagonal) then begin
        if context^.cancellationRequested then break;
        radius:=max(relativeCircleSize*image.diagonal*min(1,1/6*globalAvgDiff),1);
        circleSamples:=round(10000/sqr(radius));
        if circleSamples>31 then circleSamples:=31;
      end;
      initialize(toDraw);
      for j:=0 to circleSamples do begin
        newCircle:=randomCircle(radius);
        newCircle.color:=avgColor(copy,newCircle);
        newCircle.diff:=colDiff(avgColor(image,newCircle),newCircle.color);
        if (j=0) or (newCircle.diff>toDraw.diff) then toDraw:=newCircle;
      end;
      drawCircle(toDraw);
    end;
    copy.destroy;
  end;

PROCEDURE encircle_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  begin
    encircle(context^.image,parameters.i0,WHITE,parameters.f1,parameters.f2,context);
  end;
PROCEDURE encircleNeon_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  begin
    encircle(context^.image,parameters.i0,BLACK,parameters.f1,parameters.f2,context);
  end;
PROCEDURE halftone_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  begin
    context^.image.halftone(parameters.f1*context^.image.diagonal*0.01,parameters.i0);
  end;

PROCEDURE rectagleSplit_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  TYPE T_rectData=record
         x0,y0,x1,y1:longint;
         variance:double;
         mean:T_rgbFloatColor;
       end;
  VAR xRes,yRes:longint;
      Rectangle:T_rectData;
      rectangles:array of T_rectData;

  PROCEDURE scanRectangle(VAR r:T_rectData);
    VAR x,y:longint;
        k:longint=0;
        c,s,ss:T_rgbFloatColor;
    begin
      s :=BLACK;
      ss:=BLACK;
      for y:=max(0,r.y0) to min(r.y1,context^.image.dimensions.height)-1 do
      for x:=max(0,r.x0) to min(r.x1,context^.image.dimensions.width )-1 do begin
        c:=context^.image[x,y];
        k +=1;
        s +=c;
        ss+=c*c;
      end;
      ss-=s*s*(1/k);
      r.mean:=s*(1/k);
      if k=0
      then r.variance:=-1
      else r.variance:=(ss[cc_red]+ss[cc_green]+ss[cc_blue]);
    end;

  PROCEDURE splitRectangle;
    VAR a0,a1,b0,b1:T_rectData;
        splitIdx:longint=0;
        i:longint;
    begin
      splitIdx:=0;
      for i:=1 to length(rectangles)-1 do if rectangles[i].variance>rectangles[splitIdx].variance then splitIdx:=i;
      a0:=rectangles[splitIdx];
      a1:=rectangles[splitIdx];
      b0:=rectangles[splitIdx];
      b1:=rectangles[splitIdx];
      case byte(parameters.i1) of
        1: with rectangles[splitIdx] do begin
          if x1-x0>=y1-y0 then begin
            a0.x1:=round(x0+0.6180339887498949*(x1-x0)); a1.x0:=a0.x1;
            b0.x1:=round(x0+0.3819660112501051*(x1-x0)); b1.x0:=b0.x1;
          end else begin
            a0.y1:=round(y0+0.6180339887498949*(y1-y0)); a1.y0:=a0.y1;
            b0.y1:=round(y0+0.3819660112501051*(y1-y0)); b1.y0:=b0.y1;
          end;
          scanRectangle(a0);
          scanRectangle(a1);
          if (b0.x1<>a0.x1) or (b0.y1<>a0.y1) then begin
            scanRectangle(b0);
            scanRectangle(b1);
            if b0.variance+b1.variance<a0.variance+a1.variance then begin
              a0:=b0;
              a1:=b1;
            end;
          end;
          i:=length(rectangles);
          setLength(rectangles,i+1);
          rectangles[splitIdx]:=a0;
          rectangles[i       ]:=a1;
        end;
        2: with rectangles[splitIdx] do begin
          a0.x1:=round(x0+0.5*(x1-x0)); a1.x0:=a0.x1; b0.x1:=a0.x1; b1.x0:=a1.x0;
          a0.y1:=round(y0+0.5*(y1-y0)); a1.y1:=a0.y1; b0.y0:=a0.y1; b1.y0:=a0.y1;
          scanRectangle(a0);
          scanRectangle(a1);
          scanRectangle(b0);
          scanRectangle(b1);
          i:=length(rectangles);
          setLength(rectangles,i+3);
          rectangles[splitIdx]:=a0;
          rectangles[i       ]:=a1;
          rectangles[i+1     ]:=b0;
          rectangles[i+2     ]:=b1;
        end;
        else with rectangles[splitIdx] do begin
          if x1-x0>=y1-y0 then begin
            a0.x1:=round(x0+0.5*(x1-x0)); a1.x0:=a0.x1;
          end else begin
            a0.y1:=round(y0+0.5*(y1-y0)); a1.y0:=a0.y1;
          end;
          scanRectangle(a0);
          scanRectangle(a1);
          i:=length(rectangles);
          setLength(rectangles,i+1);
          rectangles[splitIdx]:=a0;
          rectangles[i       ]:=a1;
        end;
      end;
    end;

  VAR topEdgeLight   :double=1.1785113019775793 ;
      bottomEdgeLight:double=0.23570226039551595;
      leftEdgeLight  :double=0.47140452079103179;
      rightEdgeLight :double=0.94280904158206336;
      borderWitdh    :double=20;

  PROCEDURE drawRectangle(CONST r:T_rectData);
    FUNCTION colorAt(CONST cx,cy:double):T_rgbFloatColor; inline;
      VAR b   :byte=0;
          d   :double=infinity;
          dn  :double;
      begin
        dn:=(cx-r.x0); if (dn<borderWitdh)            then begin b:=1; d:=dn; end;
        dn:=(r.x1-cx); if (dn<borderWitdh) and (dn<d) then begin b:=2; d:=dn; end;
        dn:=(cy-r.y0); if (dn<borderWitdh) and (dn<d) then begin b:=3; d:=dn; end;
        dn:=(r.y1-cy); if (dn<borderWitdh) and (dn<d) then begin b:=4; d:=dn; end;
        case b of
          1: result:=r.mean*leftEdgeLight;
          2: result:=r.mean*rightEdgeLight;
          3: result:=r.mean*topEdgeLight;
          4: result:=r.mean*bottomEdgeLight;
        else result:=r.mean;
        end;
      end;

    VAR x,y:longint;
        sum:T_rgbFloatColor;
        ix,iy:longint;
    begin
      with r do for y:=max(0,y0) to min(y1,context^.image.dimensions.height)-1 do
                for x:=max(0,x0) to min(x1,context^.image.dimensions.width )-1 do begin
        sum:=BLACK;
        for ix:=0 to 4 do for iy:=0 to 4 do sum+=colorAt(x+(ix+0.5)/5,y+(iy+0.5)/5);
        context^.image.pixel[x,y]:=sum*0.04;
      end;
    end;

  begin
    borderWitdh:=parameters.f2/1000*context^.image.diagonal;
    topEdgeLight   :=max(0,cos(parameters.f3*0.017453292519943295)+sin(parameters.f3*0.017453292519943295)*  2/3 );
    bottomEdgeLight:=max(0,cos(parameters.f3*0.017453292519943295)+sin(parameters.f3*0.017453292519943295)*(-2/3));
    leftEdgeLight  :=max(0,cos(parameters.f3*0.017453292519943295)+sin(parameters.f3*0.017453292519943295)*(-1/3));
    rightEdgeLight :=max(0,cos(parameters.f3*0.017453292519943295)+sin(parameters.f3*0.017453292519943295)*( 1/3));
    xRes:=context^.image.dimensions.width;
    yRes:=context^.image.dimensions.height;
    setLength(rectangles,1);
    with rectangles[0] do begin
      x1:=max(xRes,yRes);
      y0:=(yRes-x1) div 2; y1:=x1+y0;
      x0:=(xRes-x1) div 2; x1   +=x0;
    end;
    while (length(rectangles)<parameters.i0) and not(context^.cancellationRequested) do splitRectangle;
    for Rectangle in rectangles do drawRectangle(Rectangle);
    setLength(rectangles,0);
  end;

INITIALIZATION
registerSimpleOperation(imc_misc,
  newParameterDescription('sketch',pt_4floats)^
    .setDefaultValue('1,0.1,0.8,0.2')^
    .addChildParameterDescription(spa_f0,'cover'          ,pt_float,0)^
    .addChildParameterDescription(spa_f1,'direction sigma',pt_float,0)^
    .addChildParameterDescription(spa_f2,'density'        ,pt_float)^
    .addChildParameterDescription(spa_f3,'tolerance'      ,pt_float,0),
  @sketch_impl);
registerSimpleOperation(imc_misc,
  newParameterDescription('drip',pt_2floats,0,1)^
    .setDefaultValue('0.1,0.01')^
    .addChildParameterDescription(spa_f0,'diffusiveness',pt_float,0,1)^
    .addChildParameterDescription(spa_f1,'range' ,pt_float,0,1),
  @drip_impl);
registerSimpleOperation(imc_misc,
  newParameterDescription('encircle',pt_1I2F,0)^
    .setDefaultValue('2000,0.5,0.2')^
    .addChildParameterDescription(spa_i0,'circle count',pt_integer,1,100000)^
    .addChildParameterDescription(spa_f1,'opacity' ,pt_float,0,1)^
    .addChildParameterDescription(spa_f2,'circle size' ,pt_float,0),
  @encircle_impl);
registerSimpleOperation(imc_misc,
  newParameterDescription('encircleNeon',pt_1I2F,0)^
    .setDefaultValue('2000,0.5,0.2')^
    .addChildParameterDescription(spa_i0,'circle count',pt_integer,1,100000)^
    .addChildParameterDescription(spa_f1,'opacity' ,pt_float,0,1)^
    .addChildParameterDescription(spa_f2,'circle size' ,pt_float,0),
  @encircleNeon_impl);
registerSimpleOperation(imc_misc,
  newParameterDescription('halftone',pt_1I1F)^
    .setDefaultValue('0,0.2')^
    .addEnumChildDescription(spa_i0,'style',
    'quadratic grid on black',
    'quadratic grid on white',
    'quadratic shifted grid on black',
    'quadratic shifted grid on white',
    'hexagonal grid on black',
    'hexagonal grid on white',
    'hexagonal shifted grid on black',
    'hexagonal shifted grid on white')^
    .addChildParameterDescription(spa_f1,'scale',pt_float,0),
  @halftone_impl);
registerSimpleOperation(imc_misc,
  newParameterDescription('rectangleSplit',pt_2I2F)^
    .setDefaultValue('500,0,2,45')^
    .addChildParameterDescription(spa_i0,'count',pt_integer,2,200000)^
    .addEnumChildDescription(spa_i1,'split style',
     'half split','golden section split','quadrats split')^
    .addChildParameterDescription(spa_f2,'border width',pt_float,0)^
    .addChildParameterDescription(spa_f3,'border angle',pt_float,0,90),
  @rectagleSplit_impl);

end.

