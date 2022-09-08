UNIT ig_buddhaBrot;
INTERFACE
USES myColors,
     myParams,
     complex,
     mypics,
     imageContexts,
     imageGeneration,
     mySys;

TYPE
  P_buddhaBrot=^T_buddhaBrot;
  T_buddhaBrot=object(T_pixelThrowerAlgorithm)
    maxDepth    :longint;
    colorStyle  :byte;

    CONSTRUCTOR create;
    PROCEDURE resetParameters(CONST style:longint); virtual;
    FUNCTION numberOfParameters:longint; virtual;
    PROCEDURE setParameter(CONST index:byte; CONST value:T_parameterValue); virtual;
    FUNCTION getParameter(CONST index:byte):T_parameterValue; virtual;
    PROCEDURE prepareSlice(CONST context:P_abstractWorkflow; CONST index:longint); virtual;
  end;

IMPLEMENTATION
USES sysutils,math,darts;
CONSTRUCTOR T_buddhaBrot.create;
  CONST colName:array[0..2] of string=('White on black','Harsh','Fiery');
  begin
    inherited create;
    addParameter('Depth',pt_integer,0);
    addParameter('Coloring',pt_enum,0,2)^.setEnumValues(colName);
    resetParameters(0);
  end;

PROCEDURE T_buddhaBrot.resetParameters(CONST style: longint);
  begin
    inherited resetParameters(style);
    colorStyle  :=0;
    maxDepth    :=100;
    par_alpha   :=0.1;
  end;

FUNCTION T_buddhaBrot.numberOfParameters: longint;
  begin
    result:=inherited numberOfParameters+2;
  end;

PROCEDURE T_buddhaBrot.setParameter(CONST index: byte; CONST value: T_parameterValue);
  begin
    if index<inherited numberOfParameters then inherited setParameter(index,value)
    else case byte(index-inherited numberOfParameters) of
      0: maxDepth:=value.i0;
    else colorStyle:=value.i0;
    end;
  end;

FUNCTION T_buddhaBrot.getParameter(CONST index: byte): T_parameterValue;
  begin
    if index<inherited numberOfParameters then exit(inherited getParameter(index))
    else case byte(index-inherited numberOfParameters) of
      0: result:=parValue(index,maxDepth);
    else result:=parValue(index,colorStyle);
    end;
  end;

PROCEDURE T_buddhaBrot.prepareSlice(CONST context:P_abstractWorkflow; CONST index:longint);
  VAR XOS:T_xosPrng;
      tempMap:array of word=();
      x,y:longint;
      path:array of T_Complex;
      hitCount:longint=0;
      divergeRadius:double=1E2;

  PROCEDURE iterate();
    PROCEDURE putPixel(CONST w:T_Complex);
      VAR C:T_Complex;
          j:longint;
      begin
        c:=scaler.mrofsnart(w.re,w.im);
        c.re:=c.re+darts_delta[index,0];
        c.im:=c.im+darts_delta[index,1];
        if (c.re>-0.5) and (c.re<renderTempData.maxPixelX) and
           (c.im>-0.5) and (c.im<renderTempData.maxPixelY) then begin
          j:=round(c.re)+
             round(c.im)*renderTempData.xRes;
          if tempMap[j]<65535 then inc(tempMap[j]);
          inc(hitCount);
        end;
      end;

    VAR x,c:T_Complex;
        i:longint;
        k:longint=0;
    begin
      repeat
        x.re:=2*XOS.realRandom-1;
        x.im:=2*XOS.realRandom-1;
        c.re:=sqrabs(x);
      until (c.re<1) and (c.re<>0);
      x:=x*system.sqrt(-2*system.ln(c.re)/c.re);
      x.re-=0.5;
      c:=x;
      while isValid(x) and (sqrabs(x)<divergeRadius) and (k<length(path)) do begin
        path[k]:=x; inc(k);
        x:=sqr(x)+c;
      end;
      if   not(isValid(x))               then for i:=0 to k-2 do putPixel(path[i])
      else if (sqrabs(x)>=divergeRadius) then for i:=0 to k-1 do putPixel(path[i]);
    end;

  VAR flushFactor:double=0;
  FUNCTION updatedPixel(CONST prevColor,bgColor:T_rgbFloatColor; CONST hits:word):T_rgbFloatColor; inline;
    VAR cover:double;
        locColor:T_rgbFloatColor=(1,1,1);
    begin
      cover:=1-intpower(renderTempData.antiCoverPerSample,hits);
      case colorStyle of
        1: if cover<0.5 then cover:=0 else cover:=1;
        2: begin
          if cover<0 then cover:=0
          else if cover<1/3 then begin locColor:=rgbColor(1,0,0); cover:=3*cover;  end
          else if cover<2/3 then begin locColor:=rgbColor(1,3*cover-1,0); cover:=1; end
          else if cover<1   then begin locColor:=rgbColor(1,1,3*cover-2); cover:=1; end
          else cover:=1;
        end;
      end;
      result:=(prevColor*renderTempData.samplesFlushed+locColor*cover+bgColor*(1-cover))*flushFactor;
    end;

  begin
    with renderTempData do if index<aaSamples then begin
      with scaler.getWorldBoundingBox do begin
        divergeRadius:=max(divergeRadius,x0*x0+y0*y0);
        divergeRadius:=max(divergeRadius,x0*x0+y1*y1);
        divergeRadius:=max(divergeRadius,x1*x1+y0*y0);
        divergeRadius:=max(divergeRadius,x1*x1+y1*y1);
      end;
      XOS.create;
      XOS.randomize;
      setLength(path,maxDepth);
      with renderTempData do begin
        setLength(tempMap,xRes*yRes);
        for x:=0 to length(tempMap)-1 do tempMap[x]:=0;
      end;
      x:=0;
      while (x<timesteps) and (hitCount<timesteps) do begin
        iterate;
        inc(x);
      end;
      if not(context^.cancellationRequested) then begin
        system.enterCriticalSection(flushCs);
        flushFactor:=(1/(samplesFlushed+1));
        if hasBackground and (backgroundImage<>nil)
        then for y:=0 to yRes-1 do for x:=0 to xRes-1 do context^.image[x,y]:=updatedPixel(context^.image[x,y],backgroundImage^[x,y],tempMap[y*xRes+x])
        else for y:=0 to yRes-1 do for x:=0 to xRes-1 do context^.image[x,y]:=updatedPixel(context^.image[x,y],BLACK                ,tempMap[y*xRes+x]);
        inc(samplesFlushed);
        system.leaveCriticalSection(flushCs);
      end;
      setLength(tempMap,0);
      XOS.destroy;
    end;
  end;

FUNCTION newBuddhaBrot:P_generalImageGenrationAlgorithm; begin new(P_buddhaBrot(result),create); end;
INITIALIZATION
  registerAlgorithm('Buddhabrot',@newBuddhaBrot,true,false,false);
end.

