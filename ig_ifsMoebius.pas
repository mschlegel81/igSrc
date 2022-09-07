UNIT ig_ifsMoebius;
INTERFACE
USES myColors,
     myParams,
     complex,
     mypics,
     myGenerics,
     imageContexts,
     imageGeneration;
TYPE
  T_Trafo=record
       rgb:T_rgbFloatColor;
       a,c: array[0..1] of T_Complex;
       b,d: T_Complex;
     end;

  P_moebiusIfs=^T_moebiusIfs;
  T_moebiusIfs=object(T_pixelThrowerAlgorithm)
    par_depth  :longint;//=128;
    par_seed   :byte   ;//=3;
    par_color  :byte   ;//=0;
    par_bright :single ;//=1;
    par_symmex :byte   ;//=0;
    par_trafo  :array[0..7] of T_Trafo; //=8*5=40

    CONSTRUCTOR create;
    FUNCTION parameterResetStyles:T_arrayOfString; virtual;
    PROCEDURE resetParameters(CONST style:longint); virtual;
    FUNCTION getAlgorithmName:ansistring; virtual;
    FUNCTION numberOfParameters:longint; virtual;
    PROCEDURE setParameter(CONST index:byte; CONST value:T_parameterValue); virtual;
    FUNCTION getParameter(CONST index:byte):T_parameterValue; virtual;
    PROCEDURE prepareSlice(CONST context:P_abstractWorkflow; CONST index:longint); virtual;
    FUNCTION parameterIsGenetic(CONST index:byte):boolean; virtual;
  end;

IMPLEMENTATION
USES darts,sysutils,mySys;

CONSTRUCTOR T_moebiusIfs.create;
  CONST seedNames:array[0..3] of string=('Gauss','Circle','Line','Triangle');
        colorNames:array[0..8] of string=('Normal/b',  //0
                                           'Crisp/b',   //1
                                           'White/b',   //2
                                           'Orange/b',  //3
                                           'Normal/w',  //4
                                           'Crisp/w',   //5
                                           'Black/w',   //6
                                           'Orange/w',  //7
                                           'exact_depth'); //8
        postStepNames:array[0..9] of string=('None','Mirror X','Mirror Y','Mirror XY','Mirror Center','Rotate 3','Rotate 4','Rotate 5','Blur','Shift');
  VAR i:longint;
  begin
    inherited create;
    {0}addParameter('depth',pt_integer,1);
    {1}addParameter('seed type',pt_enum,0,2)^.setEnumValues(seedNames);
    {2}addParameter('coloring',pt_enum,0,8)^.setEnumValues(colorNames);
    {3}addParameter('brightness',pt_float,0);
    {4}addParameter('post-step',pt_enum,0,10)^.setEnumValues(postStepNames);
    for i:=0 to 7 do begin //Trafo index in triplet
      {5+5*i  } addParameter('color('+intToStr(i)+')',pt_color);
      {5+5*i+1} addParameter('a('+intToStr(i)+')',pt_4floats);
      {5+5*i+2} addParameter('b('+intToStr(i)+')',pt_2floats);
      {5+5*i+3} addParameter('c('+intToStr(i)+')',pt_4floats);
      {5+5*i+4} addParameter('d('+intToStr(i)+')',pt_2floats);
    end;
    resetParameters(0);
  end;

FUNCTION T_moebiusIfs.parameterResetStyles: T_arrayOfString;
  begin
    result:='Zero';                       //0
    append(result,'Random');              //1
    append(result,'linear IFS');          //2
    append(result,'8-symmetric random');  //3
    append(result,'7-symmetric random');  //4
    append(result,'6-symmetric random');  //5
    append(result,'5-symmetric random');  //6
    append(result,'4-symmetric random');  //7
    append(result,'3-symmetric random');  //8
    append(result,'2-symmetric random');  //9
    append(result,'Sierpinski Triangle'); //10
    append(result,'Sierpinski Carpet');   //11
    append(result,'Barnsley Fern');       //12
    append(result,'Snowflake');           //13
    append(result,'Moebius A');           //14
    append(result,'Moebius B');           //15

  end;

PROCEDURE T_moebiusIfs.resetParameters(CONST style: longint);
  VAR i,j:longint;
      rotK:longint;
      f:double=0;
      rot:T_Complex;
  begin
    inherited resetParameters(style);
    par_depth  :=128;
    par_seed   :=0;
    par_color  :=0;
    par_bright :=1;
    par_symmex :=0;
    case style of
      0:   f:=0;
      2:   f:=sqrt(0.5);
      else f:=2;
    end;
    for i:=0 to 7 do with par_trafo[i] do begin
      if style=0
      then rgb:=rgbColor((i) and 1,
                         (i) shr 1 and 1,
                         (i) shr 2 and 1)
      else rgb:=rgbColor(random,random,random);
      a[0].re:=f*(0.5-random);
      a[0].im:=f*(0.5-random);
      a[1].re:=f*(0.5-random);
      a[1].im:=f*(0.5-random);
      b   .re:=f*2*(0.5-random);
      b   .im:=f*2*(0.5-random);
      c[0].re:=f*(0.5-random);
      c[0].im:=f*(0.5-random);
      c[1].re:=f*(0.5-random);
      c[1].im:=f*(0.5-random);
      d   .re:=f*(0.5-random);
      d   .im:=f*(0.5-random);
    end;
    if style in [2,10..20] then for i:=0 to 7 do with par_trafo[i] do begin
      c[0]:=0;
      c[1]:=0;
      d   :=1;
    end;
    case style of
     10: begin
        for i:=0 to 7 do with par_trafo[i] do begin
          a[0]:=0.5;
          a[1]:=0.5*II;
          b.re:=system.sin(2*pi*i/3)*0.5;
          b.im:=system.cos(2*pi*i/3)*0.5;
        end;
        //for i:=6 to 7 do with par_trafo[i] do begin
        //  rot.re:=system.cos(2*pi*(i-5)/3);
        //  rot.im:=system.sin(2*pi*(i-5)/3);
        //  a[0]:=rot;
        //  a[1]:=rot*II;
        //  b  :=0;
        //end;
      end;
     11: for i:=0 to 7 do with par_trafo[i] do begin
        a[0]:=1/3;
        a[1]:=1/3*II;
        case byte(i) of                  //0 1 2
          2,3,4: b.re:= 0.5;             //7   3
          1,5  : b.re:= 0  ;             //6 5 4
          0,6,7: b.re:=-0.5;
        end;
        case byte(i) of
          0,1,2: b.im:= 0.5;
          7,3  : b.im:= 0  ;
          4,5,6: b.im:=-0.5;
        end;
      end;
     12: begin
        with par_trafo[0] do begin
          a[0]:=0;
          a[1]:=0.16*II;
          b:=0;
        end;
        for i:=1 to 3 do with par_trafo[i] do begin
          a[0]:= 0.85-0.04*II;
          a[1]:= 0.04+0.85*II;
          b   :=0.16*II;
        end;
        for i:=4 to 5 do with par_trafo[i] do begin
          a[0]:= 0.2 +0.23*II;
          a[1]:=-0.26+0.22*II;
          b   :=0.16*II;
        end;
        for i:=6 to 7 do with par_trafo[i] do begin
          a[0]:=-0.15+0.26*II;
          a[1]:= 0.28+0.24*II;
          b   :=0.044*II;
        end;
      end;
      3..6: begin
        rotK:=11-style;
        for i:=1 to rotK-1 do with par_trafo[i] do begin
          rot.re:=system.cos(2*pi*i/rotK);
          rot.im:=system.sin(2*pi*i/rotK);
          a[0]:=par_trafo[0].a[0]*rot;
          a[1]:=par_trafo[0].a[1]*rot;
          b   :=par_trafo[0].b   *rot;
          c   :=par_trafo[0].c;
          d   :=par_trafo[0].d;
        end;
        for i:=rotK to 7 do with par_trafo[i] do begin
          rot.re:=system.cos(2*pi/rotK);
          rot.im:=system.sin(2*pi/rotK);
          a[0]:=exp(1-2*random+II*2*pi*random(rotK)/rotK);
          a[1]:=a[0]*II;
          b:=0;
          d:=0;
          c[0]:=exp(1-2*random+II*2*pi*random(rotK)/rotK);
          c[1]:=c[0]*II;
          if random<0.5
          then begin a[0]:=0; a[1]:=0; b:=1; end
          else begin c[0]:=0; c[1]:=0; d:=1; end;
        end;
      end;
      7,8:begin
        rotK:=11-style;
        for i:=2 to 2*rotK-1 do with par_trafo[i] do begin
          j:=i and 1;
          rot.re:=system.cos(2*pi*(i shr 1)/rotK);
          rot.im:=system.sin(2*pi*(i shr 1)/rotK);
          a[0]:=par_trafo[j].a[0]*rot;
          a[1]:=par_trafo[j].a[1]*rot;
          b   :=par_trafo[j].b   *rot;
          c   :=par_trafo[j].c;
          d   :=par_trafo[j].d;
        end;
        for i:=2*rotK to 7 do with par_trafo[i] do begin
          rot.re:=system.cos(2*pi/rotK);
          rot.im:=system.sin(2*pi/rotK);
          a[0]:=exp(1-2*random+II*2*pi*random(rotK)/rotK);
          a[1]:=a[0]*II;
          b:=0;
          d:=0;
          c[0]:=exp(1-2*random+II*2*pi*random(rotK)/rotK);
          c[1]:=c[0]*II;
          if random<0.5
          then begin a[0]:=0; a[1]:=0; b:=1; end
          else begin c[0]:=0; c[1]:=0; d:=1; end;
        end;
      end;
      9: for i:=1 to 7 do if odd(i) then with par_trafo[i] do begin
        a[0]:=par_trafo[i-1].a[0]*-1;
        a[1]:=par_trafo[i-1].a[1]*-1;
        b   :=par_trafo[i-1].b   *-1;
        c   :=par_trafo[i-1].c;
        d   :=par_trafo[i-1].d;
      end;
      13: begin
        for i:=0 to 6 do with par_trafo[i] do begin
          a[0]:=1/3;
          a[1]:=II/3;
          b:=system.cos(2*pi/6*i)+II*system.sin(2*pi/6*i);
        end;
        par_trafo[6].b:=0;
        with par_trafo[7] do begin
          a[0]:=1;
          a[1]:=II;
          b   :=0;
        end;
      end;
      14: begin
        for i:=0 to 3 do with par_trafo[i] do begin
          a[0]:=system.cos(2*pi/4*i)+II*system.sin(2*pi/4*i);
          a[1]:=a[0]*II;
          b:=0;
          c[0]:=1;
          c[1]:=II;
          d:=0.5;
        end;
        for i:=4 to 7 do with par_trafo[i] do begin
          a[0]:=system.cos(2*pi/4*i)+II*system.sin(2*pi/4*i);
          a[1]:=a[0]*II;
          b:=1;
          c[0]:=1;
          c[1]:=II;
          d:=0;
        end;
      end;
      15: begin
        for i:=0 to 7 do with par_trafo[i] do begin
          a[0]:=system.cos(2*pi/8*i)+II*system.sin(2*pi/8*i);
          a[1]:=a[0]*II;
          b:=0;
          c[0]:=1;
          c[1]:=II;
          d:=0.3;
        end;
      end;

    end;
  end;

FUNCTION T_moebiusIfs.getAlgorithmName: ansistring;
  begin
    result:='MoebiusIFS';
  end;

FUNCTION T_moebiusIfs.numberOfParameters: longint;
  begin
    result:=inherited numberOfParameters + 45;
  end;

PROCEDURE T_moebiusIfs.setParameter(CONST index: byte;
  CONST value: T_parameterValue);
  VAR i,k:longint;
  begin
    if index<inherited numberOfParameters then inherited setParameter(index,value)
    else case byte(index-inherited numberOfParameters) of
      0: par_depth:=value.i0;
      1: par_seed:=value.i0;
      2: par_color:=value.i0;
      3: par_bright:=value.f0;
      4: par_symmex:=value.i0;
      else begin
        k:=index-inherited numberOfParameters-5;
        i:=k div 5;
        k:=k mod 5;
        with par_trafo[i] do case byte(k) of
          0: rgb:=value.color;
          1: begin a[0].re:=value.f0; a[0].im:=value.f1; a[1].re:=value.f2; a[1].im:=value.f3; end;
          2: begin b   .re:=value.f0; b   .im:=value.f1; end;
          3: begin c[0].re:=value.f0; c[0].im:=value.f1; c[1].re:=value.f2; c[1].im:=value.f3; end;
          4: begin d   .re:=value.f0; d   .im:=value.f1; end;
        end;
      end;
    end;
  end;

FUNCTION T_moebiusIfs.getParameter(CONST index: byte): T_parameterValue;
  VAR i,k:longint;
  begin
    if index<inherited numberOfParameters then exit(inherited getParameter(index))
    else case byte(index-inherited numberOfParameters) of
      0: result:=parValue(index,par_depth);
      1: result:=parValue(index,par_seed);
      2: result:=parValue(index,par_color);
      3: result:=parValue(index,par_bright);
      4: result:=parValue(index,par_symmex);
      else begin
        k:=index-inherited numberOfParameters-5;
        i:=k div 5;
        k:=k mod 5;
        with par_trafo[i] do case byte(k) of
          0: result:=parValue(index,rgb);
          1: result:=parValue(index,a[0].re,a[0].im,a[1].re,a[1].im);
          2: result:=parValue(index,b.re,b.im);
          3: result:=parValue(index,c[0].re,c[0].im,c[1].re,c[1].im);
        else result:=parValue(index,d.re,d.im);
        end;
      end;
    end;
  end;

PROCEDURE T_moebiusIfs.prepareSlice(CONST context: P_abstractWorkflow;
  CONST index: longint);
  CONST abortRadius=1E3;
  VAR colorToAdd:T_rgbFloatColor=(0,0,0);
      XOS:T_xosPrng;
  PROCEDURE setColor;
    begin
      with renderTempData do case par_color of
        2,8:  colorToAdd:=WHITE*par_bright*coverPerSample;
        6:    colorToAdd:=BLACK;
        3,7:  colorToAdd:=rgbColor(1,0.5,0)*par_bright*coverPerSample;
        else  colorToAdd:=GREY*par_bright*coverPerSample;
      end;
    end;

  FUNCTION getRandomPoint:T_Complex;
    CONST ctp:array[0..2] of T_Complex=((re:0.5*system.sin(0*pi/3);im:0.5*system.cos(0*pi/3)),
                                        (re:0.5*system.sin(2*pi/3);im:0.5*system.cos(2*pi/3)),
                                        (re:0.5*system.sin(4*pi/3);im:0.5*system.cos(4*pi/3)));

    VAR xx:double;
    begin
      result:=II;
      case par_seed of
        0: begin
          repeat
            result.re:=2*XOS.realRandom-1;
            result.im:=2*XOS.realRandom-1;
            xx:=sqrabs(result);
          until (xx<1) and (xx<>0);
          result:=result*system.sqrt(-2*system.ln(xx)/xx);
        end;
        1: begin
          repeat
            result.re:=2*XOS.realRandom-1;
            result.im:=2*XOS.realRandom-1;
            xx:=sqrabs(result);
          until (xx<1) and (xx<>0);
          result:=result*0.5E-2;
        end;
        2: begin
          xx:=2*pi*XOS.realRandom;
          result.re:=0.5*system.cos(xx);
          result.im:=0.5*system.sin(xx);
        end;
        3: begin
          xx:=XOS.realRandom;
          case XOS.intRandom(3) of
            0: result:=ctp[0]+(ctp[1]-ctp[0])*xx;
            1: result:=ctp[1]+(ctp[2]-ctp[1])*xx;
            2: result:=ctp[2]+(ctp[0]-ctp[2])*xx;
          end;
        end;
      end;
    end;

  VAR temp:T_rawImage;
      blurAid:array[0..1] of double;
  PROCEDURE putPixel(px:T_Complex);
    CONST c1 =system.cos(2*pi/3); s1 =system.sin(2*pi/3);
          c2 =system.cos(4*pi/3); s2 =system.sin(4*pi/3);
          cp1=system.cos(2*pi/5); sp1=system.sin(2*pi/5);
          cp2=system.cos(4*pi/5); sp2=system.sin(4*pi/5);
          cp3=system.cos(6*pi/5); sp3=system.sin(6*pi/5);
          cp4=system.cos(8*pi/5); sp4=system.sin(8*pi/5);

    PROCEDURE put(CONST x,y:double); inline;
      VAR sx:T_Complex;
      begin
        sx:=scaler.mrofsnart(x,y);
        sx.re:=sx.re+darts_delta[index,0];
        sx.im:=sx.im+darts_delta[index,1];
        if (sx.re>-0.5) and (sx.re<renderTempData.maxPixelX) and
           (sx.im>-0.5) and (sx.im<renderTempData.maxPixelY) then
          temp.multIncPixel(round(sx.re),
                            round(sx.im),
                            renderTempData.antiCoverPerSample,
                            colorToAdd);
      end;
    VAR i,j:longint;
    begin
      if par_symmex<>9 then put(px.re,px.im);
      case par_symmex of
        1: put(-px.re,px.im);
        2: put(px.re,-px.im);
        3: begin
          put(-px.re, px.im);
          put( px.re,-px.im);
          put(-px.re,-px.im);
        end;
        4: put(-px.re,-px.im);
        5: begin
          put(c1*px.re+s1*px.im,c1*px.im-s1*px.re);
          put(c2*px.re+s2*px.im,c2*px.im-s2*px.re);
        end;
        6: begin
          put( px.im,-px.re);
          put(-px.re,-px.im);
          put(-px.im, px.re);
        end;
        7: begin
          put(cp1*px.re+sp1*px.im,cp1*px.im-sp1*px.re);
          put(cp2*px.re+sp2*px.im,cp2*px.im-sp2*px.re);
          put(cp3*px.re+sp3*px.im,cp3*px.im-sp3*px.re);
          put(cp4*px.re+sp4*px.im,cp4*px.im-sp4*px.re);
        end;
        8: for i:=0 to 1 do put(px.re*blurAid[i],px.im*blurAid[i]);
        9: for i:=-2 to 2 do for j:=-2 to 2 do put(px.re+i,px.im+j);
      end;
    end;

  VAR x,y,k:longint;
      farawayCount:longint;
      t,dt:double;
      px:T_Complex;
  begin
    with renderTempData do if index<aaSamples then begin
      XOS.create;
      XOS.randomize;
      with renderTempData do begin
        if hasBackground and (backgroundImage<>nil)
        then temp.create(backgroundImage^)
        else begin
          temp.create(xRes,yRes);
          if par_color in [0..3,8]
          then for y:=0 to yRes-1 do for x:=0 to xRes-1 do temp[x,y]:=BLACK
          else for y:=0 to yRes-1 do for x:=0 to xRes-1 do temp[x,y]:=WHITE;
        end;
        system.enterCriticalSection(flushCs);
        if par_color=8
        then dt:=2          /timesteps
        else dt:=2*par_depth/timesteps;
        t:=-1+dt*samplesFlushed/aaSamples;
        system.leaveCriticalSection(flushCs);
      end;
      setColor;
      if par_color=8 then while t<1 do begin
        px:=getRandomPoint;
        farawayCount:=0;
        if par_symmex=8 then begin
          blurAid[0]:=1-0.5*abs(XOS.realRandom+XOS.realRandom-1);
          blurAid[1]:=1-0.5*abs(XOS.realRandom+XOS.realRandom-1);
        end;
        for k:=1 to par_depth do begin
          with par_trafo[XOS.intRandom(8)] do
            px:=(a[0]*px.re+a[1]*px.im+b)/
                (c[0]*px.re+c[1]*px.im+d);
          if (sqrabs(px)>abortRadius) then begin
            inc(farawayCount);
            if farawayCount>4 then break;
          end else farawayCount:=0;
        end;
        if farawayCount<4 then putPixel(px);
        t+=dt;
      end else while t<1 do begin
        px:=getRandomPoint;
        farawayCount:=0;
        if par_symmex=8 then begin
          blurAid[0]:=1-0.5*abs(XOS.realRandom+XOS.realRandom-1);
          blurAid[1]:=1-0.5*abs(XOS.realRandom+XOS.realRandom-1);
        end;
        for k:=-(par_depth shr 3) to par_depth do begin
          with par_trafo[XOS.intRandom(8)] do begin
            px:=(a[0]*px.re+a[1]*px.im+b)/
                (c[0]*px.re+c[1]*px.im+d);
            case par_color of
              0,4: colorToAdd:=(colorToAdd*0.5)+(rgb*par_bright*coverPerSample);
              1,5: colorToAdd:=rgb*par_bright*coverPerSample;
            end;
          end;
          if k>=0 then putPixel(px);
          if (sqrabs(px)>abortRadius) then begin
            inc(farawayCount);
            if farawayCount>4 then break;
          end else farawayCount:=0;
        end;
        t+=dt;
      end;

      if not(context^.cancellationRequested) then begin
        system.enterCriticalSection(flushCs);
        t:=1/(samplesFlushed+1);
        for y:=0 to yRes-1 do for x:=0 to xRes-1 do context^.image[x,y]:=(context^.image[x,y]*samplesFlushed+temp[x,y])*t;
        inc(samplesFlushed);
        system.leaveCriticalSection(flushCs);
      end;
      temp.destroy;
      XOS.destroy;
    end;
  end;

FUNCTION T_moebiusIfs.parameterIsGenetic(CONST index: byte): boolean;
  begin
    result:=inherited parameterIsGenetic(index) and (index<>inherited numberOfParameters+3);
  end;

FUNCTION newIfs:P_generalImageGenrationAlgorithm; begin new(P_moebiusIfs(result),create); end;
INITIALIZATION
  registerAlgorithm('MoebiusIFS',@newIfs,true,false,false);
end.
