UNIT im_triangleSplit;
INTERFACE
IMPLEMENTATION
USES imageManipulation,imageContexts,myParams,mypics,myColors,math,pixMaps,darts,complex;

TYPE T_quad=record
       p0,p1,p2,p3:T_Complex;
       color:T_rgbFloatColor;
       isTriangle:boolean;
     end;
     T_quadList=array of T_quad;

     T_boundingBox=record
       x0,y0,x1,y1:longint;
     end;

FUNCTION areaMeasure(CONST a,b:T_Complex; CONST x2,y2:double):double; inline;
  begin
    result:=(b.re-a.re)*(y2-a.im)-
            (b.im-a.im)*(x2-a.re);
  end;

FUNCTION isInside(CONST x,y:double; CONST q:T_quad):boolean;
  begin
    if q.isTriangle
    then result:=(areaMeasure(q.p0,q.p1,x,y)>=0) and
                 (areaMeasure(q.p1,q.p2,x,y)>=0) and
                 (areaMeasure(q.p2,q.p0,x,y)>=0)
    else result:=(areaMeasure(q.p0,q.p1,x,y)>=0) and
                 (areaMeasure(q.p1,q.p2,x,y)>=0) and
                 (areaMeasure(q.p2,q.p3,x,y)>=0) and
                 (areaMeasure(q.p3,q.p0,x,y)>=0);
  end;

FUNCTION getBoundingBox(CONST q:T_quad):T_boundingBox;
  begin
    result.x0:=floor(min(q.p0.re,min(q.p1.re,min(q.p2.re,q.p3.re))));
    result.y0:=floor(min(q.p0.im,min(q.p1.im,min(q.p2.im,q.p3.im))));
    result.x1:=ceil (max(q.p0.re,max(q.p1.re,max(q.p2.re,q.p3.re))))+1;
    result.y1:=ceil (max(q.p0.im,max(q.p1.im,max(q.p2.im,q.p3.im))))+1;
  end;

FUNCTION bbIntersect(CONST b1,b2:T_boundingBox):T_boundingBox;
  begin
    result.x0:=max(b1.x0,b2.x0); result.y0:=max(b1.y0,b2.y0);
    result.x1:=min(b1.x1,b2.x1); result.y1:=min(b1.y1,b2.y1);
  end;

FUNCTION quadIsInBoundingBox(CONST q:T_quad; CONST box:T_boundingBox):boolean;
  CONST outerLeft =1;
        outerRight=2;
        outerUp   =4;
        outerDown =8;
  VAR out0:byte=0;
      out1:byte=0;
  begin
    if q.p0.re<box.x0 then out0+=outerLeft else if q.p0.re>=box.x1 then out0+=outerRight;
    if q.p0.im<box.y0 then out0+=outerUp   else if q.p0.im>=box.y1 then out0+=outerDown;
    if q.p1.re<box.x0 then out1+=outerLeft else if q.p1.re>=box.x1 then out1+=outerRight;
    if q.p1.im<box.y0 then out1+=outerUp   else if q.p1.im>=box.y1 then out1+=outerDown;
    out0:=out0 and out1;
    if out0=0 then exit(true);
    out1:=0;
    if q.p2.re<box.x0 then out1+=outerLeft else if q.p2.re>=box.x1 then out1+=outerRight;
    if q.p2.im<box.y0 then out1+=outerUp   else if q.p2.im>=box.y1 then out1+=outerDown;
    out0:=out0 and out1;
    if (out0=0) or (q.isTriangle) then exit(out0=0);
    out1:=0;
    if q.p3.re<box.x0 then out1+=outerLeft else if q.p3.re>=box.x1 then out1+=outerRight;
    if q.p3.im<box.y0 then out1+=outerUp   else if q.p3.im>=box.y1 then out1+=outerDown;
    out0:=out0 and out1; result:=out0=0;
  end;

TYPE
P_trianglesTodo=^T_trianglesTodo;
T_trianglesTodo=object(T_parallelTask)
  chunkIndex:longint;
  quadsInRange:T_quadList;

  CONSTRUCTOR create(CONST allCircles:T_quadList;
                     CONST chunkIndex_:longint;
                     CONST target_:P_rawImage);
  DESTRUCTOR destroy; virtual;
  PROCEDURE execute; virtual;
end;

CONSTRUCTOR T_trianglesTodo.create(CONST allCircles: T_quadList; CONST chunkIndex_: longint; CONST target_: P_rawImage);
  VAR box:T_boundingBox;
      i:longint;
      c:T_quad;
  begin
    box.x0:=0;
    box.y0:=0;
    chunkIndex :=chunkIndex_;
    with box do for i:=0 to chunkIndex-1 do begin
      inc(x0,CHUNK_BLOCK_SIZE);
      if x0>=target_^.dimensions.width then begin
        x0:=0;
        inc(y0,CHUNK_BLOCK_SIZE);
      end;
    end;
    box.x1:=box.x0+CHUNK_BLOCK_SIZE;
    box.y1:=box.y0+CHUNK_BLOCK_SIZE;

    setLength(quadsInRange,1);
    i:=0;
    for c in allCircles do if quadIsInBoundingBox(c,box) then begin
      if i>=length(quadsInRange) then setLength(quadsInRange,i*2);
      quadsInRange[i]:=c;
      inc(i);
    end;
    setLength(quadsInRange,i);
  end;

DESTRUCTOR T_trianglesTodo.destroy;
  begin
    setLength(quadsInRange,0);
  end;

PROCEDURE T_trianglesTodo.execute;
  FUNCTION getColorAt(CONST x,y:double):T_rgbFloatColor;
    VAR q:T_quad;
    begin
      result:=BLACK;
      for q in quadsInRange do if isInside(x,y,q) then exit(q.color);
    end;

  VAR chunk:T_colChunk;
      i,j,k,k0,k1:longint;
  begin
    chunk.create;
    chunk.initForChunk(containedIn^.image.dimensions.width,containedIn^.image.dimensions.height,chunkIndex);

    for i:=0 to chunk.width-1 do for j:=0 to chunk.height-1 do with chunk.col[i,j] do rest:=getColorAt(chunk.getPicX(i),chunk.getPicY(j));
    if not(containedIn^.previewQuality) then
    while chunk.markAlias(0.5) and not(containedIn^.cancellationRequested) do
    for i:=0 to chunk.width-1 do for j:=0 to chunk.height-1 do with chunk.col[i,j] do if odd(antialiasingMask) then begin
      if antialiasingMask=1 then begin
        k0:=1;
        k1:=2;
        antialiasingMask:=2;
        k1:=2*k1;
      end else begin
        k0:=antialiasingMask-1;
        k1:=k0+2;
        if k1>254 then k1:=254;
        antialiasingMask:=k1;
        k0:=2*k0;
        k1:=2*k1;
      end;
      for k:=k0 to k1-1 do rest:=rest+getColorAt(
        chunk.getPicX(i)+darts_delta[k,0],
        chunk.getPicY(j)+darts_delta[k,1]);
    end;

    containedIn^.image.copyFromChunk(chunk);
    chunk.destroy;
  end;

PROCEDURE triangleSplit(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  TYPE T_triangleInfo=record
         base:T_quad;
         variance:double;
       end;
  VAR imgBB:T_boundingBox;
  PROCEDURE scanTriangle(VAR triangleInfo:T_triangleInfo);
    VAR box:T_boundingBox;
        x,y:longint;
        k:longint=0;
        c,s,ss:T_rgbFloatColor;
    begin
      box:=bbIntersect(imgBB,getBoundingBox(triangleInfo.base));
      s :=BLACK;
      ss:=BLACK;
      for y:=box.y0 to box.y1-1 do
      for x:=box.x0 to box.x1-1 do if isInside(x,y,triangleInfo.base) then begin
        c:=context^.image[x,y];
        k +=1;
        s +=c;
        ss+=c*c;
      end;
      ss-=s*s*(1/k);
      triangleInfo.base.color:=s*(1/k);
      if k=0
      then triangleInfo.variance:=-1
      else triangleInfo.variance:=(ss[cc_red]+ss[cc_green]+ss[cc_blue]);
    end;

  VAR tri:array of T_triangleInfo;
  PROCEDURE initTriangles;
    VAR x0,y0,x1,y1:double;
        a,b,c,d:T_Complex;
    begin
      x1:=max(imgBB.x1,imgBB.y1);
      y0:=(imgBB.y1-round(x1)) div 2; y1:=x1+y0;
      x0:=(imgBB.x1-round(x1)) div 2; x1   +=x0;
      a.re:=x0; a.im:=y0;
      b.re:=x1; b.im:=y0;
      c.re:=x1; c.im:=y1;
      d.re:=x0; d.im:=y1;

      setLength(tri,2);
      with tri[0] do begin
        base.p0:=a;
        base.p1:=b;
        base.p2:=c;
        base.p3:=c;
        base.isTriangle:=true;
      end;
      scanTriangle(tri[0]);
      with tri[1] do begin
        base.p0:=a;
        base.p1:=c;
        base.p2:=d;
        base.p3:=d;
        base.isTriangle:=true;
      end;
      scanTriangle(tri[1]);
    end;

  PROCEDURE splitTriangles;
    VAR toSplit:longint=0;
        i:longint;
        edgeToSplit:byte=0;
        l,l2:double;
        a0,a1,b0,b1,c0,c1:T_triangleInfo;
    begin
      for i:=1 to length(tri)-1 do if tri[i].variance>tri[toSplit].variance then toSplit:=i;
      a0:=tri[toSplit];
      a1:=tri[toSplit];
      b0:=tri[toSplit];
      b1:=tri[toSplit];
      c0:=tri[toSplit];
      c1:=tri[toSplit];
      with tri[toSplit] do begin
        l:= sqrabs(base.p1-base.p0);
        l2:=sqrabs(base.p2-base.p1);
        if l2>l then begin l:=l2; edgeToSplit:=1; end;
        l2:=sqrabs(base.p0-base.p2);
        if l2>l then              edgeToSplit:=2;
      end;
      case edgeToSplit of
        0: begin
          a0.base.p1:=a0.base.p0*0.5 +a0.base.p1*0.5 ; a1.base.p0:=a0.base.p1;
          b0.base.p1:=b0.base.p0*0.33+b0.base.p1*0.67; b1.base.p0:=b0.base.p1;
          c0.base.p1:=c0.base.p0*0.67+c0.base.p1*0.33; c1.base.p0:=c0.base.p1;
        end;
        1: begin
          a0.base.p2:=a0.base.p1*0.5 +a0.base.p2*0.5 ; a1.base.p1:=a0.base.p2; a0.base.p3:=a0.base.p2;
          b0.base.p2:=b0.base.p1*0.5 +b0.base.p2*0.5 ; b1.base.p1:=b0.base.p2; b0.base.p3:=b0.base.p2;
          c0.base.p2:=c0.base.p1*0.5 +c0.base.p2*0.5 ; c1.base.p1:=c0.base.p2; c0.base.p3:=c0.base.p2;
        end;
        2: begin
          a0.base.p2:=a0.base.p2*0.5 +a0.base.p0*0.5 ; a1.base.p0:=a0.base.p2; a0.base.p3:=a0.base.p2;
          b0.base.p2:=b0.base.p2*0.5 +b0.base.p0*0.5 ; b1.base.p0:=b0.base.p2; b0.base.p3:=b0.base.p2;
          c0.base.p2:=c0.base.p2*0.5 +c0.base.p0*0.5 ; c1.base.p0:=c0.base.p2; c0.base.p3:=c0.base.p2;
        end;
      end;
      scanTriangle(a0); scanTriangle(a1);
      scanTriangle(b0); scanTriangle(b1);
      scanTriangle(c0); scanTriangle(c1);
      if b0.variance+b1.variance<a0.variance+a1.variance then begin a0:=b0; a1:=b1; end;
      if c0.variance+c1.variance<a0.variance+a1.variance then begin a0:=c0; a1:=c1; end;
      i:=length(tri);
      setLength(tri,i+1);
      tri[toSplit]:=a0;
      tri[i      ]:=a1;
    end;

  PROCEDURE startRendering;
    VAR allQuads:T_quadList;
        quadCount:longint=0;

    PROCEDURE addQuad(CONST a,b,c,d:T_Complex; CONST color:T_rgbFloatColor);
      begin
        if quadCount>=length(allQuads) then setLength(allQuads,round(1.1*length(allQuads)));
        allQuads[quadCount].p0:=a;
        allQuads[quadCount].p1:=b;
        allQuads[quadCount].p2:=c;
        allQuads[quadCount].p3:=d;
        allQuads[quadCount].isTriangle:=false;
        allQuads[quadCount].color:=color;
        inc(quadCount);
      end;

    PROCEDURE addTriangle(CONST a,b,c:T_Complex; CONST color:T_rgbFloatColor);
      begin
        addQuad(a,b,c,c,color);
        allQuads[quadCount-1].isTriangle:=true;
      end;

    FUNCTION edgeCut(CONST a,b,c,d:T_Complex):T_Complex;
      VAR X,Y,Z:T_Complex;
          u:double;
      begin
        X:=b-a;
        Y:=d-c;
        Z:=c-a;
        u:=(Z.re*Y.im-Y.re*Z.im)/(X.re*Y.im-Y.re*X.im);
        result:=a+X*u;
      end;

    VAR BorderWidth:double;
    PROCEDURE shiftEdge(CONST a,b:T_Complex; OUT a_,b_:T_Complex);
      VAR d:T_Complex;
      begin
        d.re:=a.im-b.im;
        d.im:=b.re-a.re;
        d*=BorderWidth/abs(d);
        a_:=a+d;
        b_:=b+d;
      end;

    VAR borderUpFraction,borderAcrossFraction:double;
    PROCEDURE toRenderables(CONST q:T_quad);
      VAR abs,BCs,CAs:array[0..1] of T_Complex;
          A_,B_,C_:T_Complex;
      FUNCTION colorOfSide(CONST side:byte):T_rgbFloatColor;
        VAR d:T_Complex;
        begin
          case side of
            0: d:=q.p1-q.p0;
            1: d:=q.p2-q.p1;
            2: d:=q.p0-q.p2;
          else exit(q.color);
          end;
          d:=d*II/complex.abs(d);
          result:=q.color*max(0,borderAcrossFraction*d.re*1/3
                               +borderAcrossFraction*d.im*2/3
                               +borderUpFraction);
        end;

      begin
        if (BorderWidth<0.2) or (borderAcrossFraction<0.05) then begin
          addTriangle(q.p0,q.p1,q.p2,q.color);
          exit;
        end;
        shiftEdge(q.p0,q.p1,abs[0],abs[1]);
        shiftEdge(q.p1,q.p2,BCs[0],BCs[1]);
        shiftEdge(q.p2,q.p0,CAs[0],CAs[1]);
        A_:=edgeCut(abs[0],abs[1],CAs[0],CAs[1]);
        B_:=edgeCut(abs[0],abs[1],BCs[0],BCs[1]);
        C_:=edgeCut(CAs[0],CAs[1],BCs[0],BCs[1]);
        if (areaMeasure(q.p0,B_,C_.re,C_.im)>0) and
           (areaMeasure(A_,B_,C_.re,C_.im)<areaMeasure(q.p0,q.p1,q.p2.re,q.p2.im)) then begin
          //Slim borders: 4 quads + 1 triangle
          addTriangle(A_,B_,C_,q.color);
          addQuad(q.p0,q.p1,B_,A_,colorOfSide(0));
          addQuad(q.p1,q.p2,C_,B_,colorOfSide(1));
          addQuad(q.p2,q.p0,A_,C_,colorOfSide(2));
        end else begin
          //Broad borders: 3 triangles
          A_:=edgeCut(q.p0,A_,q.p1,B_);
          addTriangle(q.p0,q.p1,A_,colorOfSide(0));
          addTriangle(q.p1,q.p2,A_,colorOfSide(1));
          addTriangle(q.p2,q.p0,A_,colorOfSide(2));
        end;
      end;

    VAR rawTriangle:T_triangleInfo;
        todo:P_trianglesTodo;
        i:longint;
    begin
      BorderWidth:=parameters.f1/1000*context^.image.diagonal;
      borderUpFraction    :=system.cos(parameters.f2*0.017453292519943295);
      borderAcrossFraction:=system.sin(parameters.f2*0.017453292519943295);
      setLength(allQuads,100);
      for rawTriangle in tri do toRenderables(rawTriangle.base);
      setLength(allQuads,quadCount);
      setLength(tri,0);

      context^.clearQueue;
      context^.image.markChunksAsPending;
      for i:=0 to context^.image.chunksInMap-1 do begin
        new(todo,create(allQuads,i,@(context^.image)));
        context^.enqueue(todo);
      end;
      context^.waitForFinishOfParallelTasks;
    end;

  begin
    imgBB.x0:=0;
    imgBB.y0:=0;
    imgBB.x1:=context^.image.dimensions.width;
    imgBB.y1:=context^.image.dimensions.height;
    initTriangles;
    while (length(tri)<parameters.i0) and not(context^.cancellationRequested) do splitTriangles;
    startRendering;
  end;

INITIALIZATION
registerSimpleOperation(imc_misc,
  newParameterDescription('triangleSplit',pt_1I2F)^
    .setDefaultValue('500,2,45')^
    .addChildParameterDescription(spa_i0,'count',pt_integer,2,200000)^
    .addChildParameterDescription(spa_f1,'border width',pt_float,0)^
    .addChildParameterDescription(spa_f2,'border angle',pt_float,0,90),
  @triangleSplit);

end.

