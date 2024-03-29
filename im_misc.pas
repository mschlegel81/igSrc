UNIT im_misc;
INTERFACE
IMPLEMENTATION
USES imageManipulation,imageContexts,myParams,mypics,myColors,math,pixMaps;

PROCEDURE sketch_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  begin
    context^.image.sketch(parameters.f0,parameters.f1,parameters.f2,parameters.f3,@context^.cancellationRequested);
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
        3: with rectangles[splitIdx] do begin
          a0.x1:=round(x0+0.5*(x1-x0)); a1.x0:=a0.x1;
          b0.y1:=round(y0+0.5*(y1-y0)); b1.y0:=b0.y1;
          scanRectangle(a0);
          scanRectangle(a1);
          scanRectangle(b0);
          scanRectangle(b1);
          if (x1-x0)*(b0.variance+b1.variance)<(y1-y0)*(a0.variance+a1.variance) then begin
            a0:=b0;
            a1:=b1;
          end;
          i:=length(rectangles);
          setLength(rectangles,i+1);
          rectangles[splitIdx]:=a0;
          rectangles[i       ]:=a1;
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

  VAR leftNx,leftNz:double;
      topNy,topNz  :double;

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
          1: result:=simpleIlluminatedColor(r.mean, leftNx,0,leftNz);  //r.mean*leftEdgeLight;
          2: result:=simpleIlluminatedColor(r.mean,-leftNx,0,leftNz); //r.mean*rightEdgeLight;
          3: result:=simpleIlluminatedColor(r.mean,0, topNy,topNz); //r.mean*topEdgeLight;
          4: result:=simpleIlluminatedColor(r.mean,0,-topNy,topNz); //r.mean*bottomEdgeLight;
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
    topNz := cos(parameters.f3*0.017453292519943295);
    leftNz:= cos(parameters.f3*0.017453292519943295);
    topNy :=-sin(parameters.f3*0.017453292519943295);
    leftNx:=-sin(parameters.f3*0.017453292519943295);

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

PROCEDURE slope_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  VAR nx,ny:double;
      ix,iy,rx,ry:longint;
      ySlope,xSlope,col:T_rgbFloatColor;
      temp:T_rawImage;
  begin
    nx:=parameters.f0*context^.image.diagonal*1E-3;
    ny:=parameters.f1*context^.image.diagonal*1E-3;
    rx:=context^.image.dimensions.width;
    ry:=context^.image.dimensions.height;
    temp.create(context^.image);
    for iy:=0 to ry-1 do for ix:=0 to rx-1 do begin
      col:=                                 temp[ix  ,iy  ];
      if iy=0 then ySlope:=col else ySlope:=temp[ix  ,iy-1];
      if ix=0 then xSlope:=col else xSlope:=temp[ix-1,iy  ];
      context^.image[ix,iy]:=(col-xSlope)*nx+(col-ySlope)*ny;
    end;
    temp.destroy;
  end;

PROCEDURE zebra_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  VAR ix,iy,iy0,iy1,iy2:longint;
      y0,y1,y2:double;
      above,below,central:T_rgbFloatColor;
      dy:double;
      wy0,wy1u,wy1l,wy2:double;
      temp:T_rawImage;
  FUNCTION partOfTotal(VAR pixelsTotal:T_rgbFloatColor; CONST maxPart:single):T_rgbFloatColor;
    begin
      result:=rgbMin(WHITE*maxPart,pixelsTotal);
      pixelsTotal-=result;
    end;

  begin
    dy:=parameters.f0/100*context^.image.diagonal;
    if dy<1 then exit;
    y1:=context^.image.dimensions.height/2;
    while y1>0 do y1-=dy;
    temp.create(context^.image);

    context^.image.clearWithColor(BLACK);
    y2:=0;
    while y2<context^.image.dimensions.height do begin
      y0:=y1-dy*0.5; iy0:=max(0,min(temp.dimensions.height-1,floor(y0)));
                     iy1:=max(0,min(temp.dimensions.height-1,floor(y1)));
      y2:=y1+dy*0.5; iy2:=max(0,min(temp.dimensions.height-1,floor(y2)));

      //iy0   wy0=1-(y0-iy0) //the part of pixel iy0 that is below y0
      //   y0
      //
      //iy1   wy1u =   y1-iy1   //the part of pixel iy1 that is above y1
      //   y1 wy1l =1-(y1-iy1)  //the part of pixel iy1 that is below y1
      //
      //iy2   wy2=y2-iy2     //the part of the pixel iy2 that is above y2
      //   y2
      wy0 :=max(0,min(1,1-(y0-iy0)));
      wy1u:=max(0,min(1,   y1-iy1 ));
      wy1l:=1-wy1u;
      wy2 :=max(0,min(1,   y2-iy2 ));
      if iy0=iy1 then begin
        //same pixel, avoid double weighting
        //iy0=iy1---------------------------------------------
        //   y0---\
        //         weight between
        //   y1---/
        //iy0+1=iy1+1-----------------------------------------
        wy1u:=y1-y0;
        wy0 :=0;
      end;
      if iy1=iy2 then begin
        //same pixel, avoid double weighting
        //iy1=iy2---------------------------------------------
        //   y1---\
        //         weight between
        //   y2---/
        //iy1+1=iy2+1-----------------------------------------
        wy1l:=y2-y1;
        wy2 :=0;
      end;

      for ix:=0 to context^.image.dimensions.width-1 do begin
        central:=temp[ix,iy1];
        above  :=temp[ix,iy0]*wy0+central*wy1u;
        below  :=temp[ix,iy2]*wy2+central*wy1l;
        for iy:=iy0+1 to iy1-1 do above  +=temp[ix,iy];
        for iy:=iy1+1 to iy2-1 do below  +=temp[ix,iy];
        context^.image[ix,iy1]                              :=context^.image[ix,iy1]+partOfTotal(above,wy1u)
                                                                                    +partOfTotal(below,wy1l);
        for iy:=iy1-1 downto iy0+1 do context^.image[ix,iy ]:=                       partOfTotal(above,1);
                                      context^.image[ix,iy0]:=context^.image[ix,iy0]+partOfTotal(above,wy0);
        for iy:=iy1+1 to     iy2-1 do context^.image[ix,iy ]:=                       partOfTotal(below,1);
                                      context^.image[ix,iy2]:=context^.image[ix,iy2]+partOfTotal(below,wy2);
      end;
      y1+=dy;
    end;
    temp.destroy;
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
    .setDefaultValue('2000,0,1,20')^
    .addChildParameterDescription(spa_i0,'count',pt_integer,2,200000)^
    .addEnumChildDescription(spa_i1,'split style',
     'half split','golden section split','quadrats split','half adaptive split')^
    .addChildParameterDescription(spa_f2,'border width',pt_float,0)^
    .addChildParameterDescription(spa_f3,'border angle',pt_float,0,90),
  @rectagleSplit_impl);
registerSimpleOperation(imc_misc,
  newParameterDescription('slope',pt_2floats)^
    .setDefaultValue('0.7,-0.7')^
    .addChildParameterDescription(spa_f0,'nx',pt_float)^
    .addChildParameterDescription(spa_f1,'ny',pt_float),
    @slope_impl);
registerSimpleOperation(imc_misc,
  newParameterDescription('zebra',pt_float,0.0001)^
    .setDefaultValue('1.0'),
    @zebra_impl);

end.

