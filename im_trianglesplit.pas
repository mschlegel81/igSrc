UNIT im_triangleSplit;
INTERFACE
USES complex,myColors,imageContexts;
TYPE
  T_quad=record
    p0,p1,p2,p3:T_Complex;
    color:T_rgbFloatColor;
    isTriangle:boolean;
  end;

  T_quadList=array of T_quad;

  T_boundingBox=record
    x0,y0,x1,y1:longint;
  end;

  T_complexPair=array[0..1] of T_Complex;

  T_tileBuilder=object
    private
      drawable        :T_quadList;
      drawableCount   :longint;
      imageBoundingBox:T_boundingBox;
      flat            :boolean; //true depending on border width and angle
      BorderWidth         ,
      borderUpFraction    ,
      borderAcrossFraction:double;
      context:P_abstractWorkflow;

      PROCEDURE addFlatTriangle(CONST a,b,c  :T_Complex; CONST color:T_rgbFloatColor);
      PROCEDURE addFlatQuad    (CONST a,b,c,d:T_Complex; CONST color:T_rgbFloatColor);

      FUNCTION shiftEdge(CONST a,b:T_Complex):T_complexPair;
      FUNCTION colorOfSide(CONST a,b:T_Complex; CONST baseColor:T_rgbFloatColor):T_rgbFloatColor;
    public
      CONSTRUCTOR create(CONST workflow:P_abstractWorkflow; CONST relativeBorderWidth,borderAngleInDegrees:double);
      DESTRUCTOR destroy;

      PROCEDURE addTriangle(CONST q:T_quad);
      PROCEDURE addTriangle(CONST a,b,c:T_Complex; CONST color:T_rgbFloatColor);
      {The color is given by the image}
      PROCEDURE addTriangle(CONST a,b,c:T_Complex);

      PROCEDURE addQuad(CONST q:T_quad);
      PROCEDURE addQuad(CONST a,b,c,d:T_Complex; CONST color:T_rgbFloatColor);
      {The color is given by the image}
      PROCEDURE addQuad(CONST a,b,c,d:T_Complex);

      PROCEDURE addHexagon(CONST a,b,c,d,e,f:T_Complex; CONST color:T_rgbFloatColor);
      {The color is given by the image}
      PROCEDURE addHexagon(CONST a,b,c,d,e,f:T_Complex);

      PROCEDURE startExecution;
  end;

IMPLEMENTATION
USES imageManipulation,myParams,mypics,math,pixMaps,darts,ig_circlespirals,sysutils;

FUNCTION crossProduct(CONST a,b:T_Complex; CONST x2,y2:double):double; inline;
  begin
    result:=(b.re-a.re)*(y2-a.im)-
            (b.im-a.im)*(x2-a.re);
  end;

FUNCTION isInside(CONST x,y:double; CONST q:T_quad):boolean;
  begin
    if q.isTriangle
    then result:=(crossProduct(q.p0,q.p1,x,y)>=0) and
                 (crossProduct(q.p1,q.p2,x,y)>=0) and
                 (crossProduct(q.p2,q.p0,x,y)>=0)
    else result:=(crossProduct(q.p0,q.p1,x,y)>=0) and
                 (crossProduct(q.p1,q.p2,x,y)>=0) and
                 (crossProduct(q.p2,q.p3,x,y)>=0) and
                 (crossProduct(q.p3,q.p0,x,y)>=0);
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

{Use this only for pixel coordinates. Otherwise the epsilon is too large.}
FUNCTION almostEqual(CONST a,b:T_Complex):boolean; inline;
  begin result:=(abs(a.re-b.re)<1E-3) and (abs(a.im-b.im)<1E-3); end;

PROCEDURE T_tileBuilder.addFlatTriangle(CONST a, b, c: T_Complex; CONST color: T_rgbFloatColor);
  begin
    //Only add triangles if orientation fits and the area is larger than epsilon
    if crossProduct(a,b,c.re,c.im)<1E-3 then exit;
    addFlatQuad(a,b,c,a,color);
    drawable[drawableCount-1].isTriangle:=true;
  end;

PROCEDURE T_tileBuilder.addFlatQuad(CONST a, b, c, d: T_Complex; CONST color: T_rgbFloatColor);
  begin
    //Only add triangles if orientation fits and the area is larger than epsilon
    if crossProduct(a,b,c.re,c.im)+crossProduct(c,d,a.re,a.im)<1E-3 then exit;
    if drawableCount>=length(drawable) then setLength(drawable,1+round(length(drawable)*1.1));
    with drawable[drawableCount] do begin
      p0:=a;
      p1:=b;
      p2:=c;
      p3:=d;
      isTriangle:=false;
      //Check for degeneration to triangle
      if      almostEqual(p3,p0) then begin p0:=p1; p1:=p2; p2:=p3; p3:=p0; isTriangle:=true; end
      else if almostEqual(p0,p1) then begin         p1:=p2; p2:=p3; p3:=p0; isTriangle:=true; end
      else if almostEqual(p1,p2) then begin                 p2:=p3; p3:=p0; isTriangle:=true; end
      else if almostEqual(p2,p3) then begin                         p3:=p0; isTriangle:=true; end;
    end;
    drawable[drawableCount].color:=color;
    inc(drawableCount);
  end;

CONSTRUCTOR T_tileBuilder.create(CONST workflow: P_abstractWorkflow; CONST relativeBorderWidth, borderAngleInDegrees: double);
  begin
    setLength(drawable,1);
    drawableCount:=0;
    context:=workflow;
    BorderWidth:=relativeBorderWidth/1000*context^.image.diagonal;
    borderUpFraction    :=system.cos(borderAngleInDegrees*0.017453292519943295);
    borderAcrossFraction:=system.sin(borderAngleInDegrees*0.017453292519943295);
    flat:=(BorderWidth<0.2) or (borderAcrossFraction<0.05);
    imageBoundingBox.x0:=0;
    imageBoundingBox.y0:=0;
    imageBoundingBox.x1:=context^.image.dimensions.width;
    imageBoundingBox.y1:=context^.image.dimensions.height;
  end;

DESTRUCTOR T_tileBuilder.destroy;
  begin
    setLength(drawable,0);
  end;

FUNCTION T_tileBuilder.shiftEdge(CONST a,b:T_Complex):T_complexPair;
  VAR d:T_Complex;
  begin
    d.re:=a.im-b.im;
    d.im:=b.re-a.re;
    d*=BorderWidth/abs(d);
    result[0]:=a+d;
    result[1]:=b+d;
  end;

FUNCTION T_tileBuilder.colorOfSide(CONST a,b:T_Complex; CONST baseColor:T_rgbFloatColor):T_rgbFloatColor;
  VAR d:T_Complex;
  begin
    d:=b-a;
    d:=d*II/complex.abs(d);
    result:=baseColor*max(0,borderAcrossFraction*d.re*1/3
                           +borderAcrossFraction*d.im*2/3
                           +borderUpFraction);
  end;

PROCEDURE T_tileBuilder.addTriangle(CONST q: T_quad);
  begin
    addTriangle(q.p0,q.p1,q.p2,q.color);
  end;

PROCEDURE T_tileBuilder.addQuad(CONST q: T_quad);
  begin
    addQuad(q.p0,q.p1,q.p2,q.p3);
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

FUNCTION edgeCut(CONST edge1,edge2:T_complexPair):T_Complex;
  begin
    result:=edgeCut(edge1[0],edge1[1],edge2[0],edge2[1]);
  end;

PROCEDURE T_tileBuilder.addTriangle(CONST a, b, c: T_Complex; CONST color: T_rgbFloatColor);
  VAR ab_shifted,
      bc_shifted,
      ca_shifted:T_complexPair;
      a_,b_,c_,X:T_Complex;
  begin
    if flat then begin
      addFlatTriangle(a,b,c,color);
      exit;
    end;
    ab_shifted:=shiftEdge(a,b);
    bc_shifted:=shiftEdge(b,c);
    ca_shifted:=shiftEdge(c,a);
    a_:=edgeCut(ab_shifted,ca_shifted);
    b_:=edgeCut(ab_shifted,bc_shifted);
    c_:=edgeCut(ca_shifted,bc_shifted);
    X:=edgeCut(a,a_,b,b_);
    if sqrabs(X-a)<sqrabs(a_-a) then a_:=X;
    if sqrabs(X-b)<sqrabs(b_-b) then b_:=X;
    X:=edgeCut(b,b_,c,c_);
    if sqrabs(X-b)<sqrabs(b_-b) then b_:=X;
    if sqrabs(X-c)<sqrabs(c_-c) then c_:=X;
    X:=edgeCut(c,c_,a,a_);
    if sqrabs(X-c)<sqrabs(c_-c) then c_:=X;
    if sqrabs(X-a)<sqrabs(a_-a) then a_:=X;
    addFlatTriangle(a_,b_,c_,color);
    addFlatQuad(a,b,b_,a_,colorOfSide(a,b,color));
    addFlatQuad(b,c,c_,b_,colorOfSide(b,c,color));
    addFlatQuad(c,a,a_,c_,colorOfSide(c,a,color));
  end;

PROCEDURE T_tileBuilder.addQuad(CONST a, b, c, d: T_Complex; CONST color: T_rgbFloatColor);
  VAR ab_shifted,
      bc_shifted,
      cd_shifted,
      da_shifted:T_complexPair;
      a_,b_,c_,d_,X:T_Complex;
  begin
    if flat then begin
      addFlatQuad(a,b,c,d,color);
      exit;
    end;
    ab_shifted:=shiftEdge(a,b);
    bc_shifted:=shiftEdge(b,c);
    cd_shifted:=shiftEdge(c,d);
    da_shifted:=shiftEdge(d,a);
    a_:=edgeCut(ab_shifted,da_shifted);
    b_:=edgeCut(ab_shifted,bc_shifted);
    c_:=edgeCut(cd_shifted,bc_shifted);
    d_:=edgeCut(cd_shifted,da_shifted);

    X:=edgeCut(a,a_,b,b_);
    if sqrabs(X-a)<sqrabs(a_-a) then a_:=X;
    if sqrabs(X-b)<sqrabs(b_-b) then b_:=X;
    X:=edgeCut(b,b_,c,c_);
    if sqrabs(X-b)<sqrabs(b_-b) then b_:=X;
    if sqrabs(X-c)<sqrabs(c_-c) then c_:=X;
    X:=edgeCut(c,c_,d,d_);
    if sqrabs(X-c)<sqrabs(c_-c) then c_:=X;
    if sqrabs(X-d)<sqrabs(d_-d) then d_:=X;
    X:=edgeCut(d,d_,a,a_);
    if sqrabs(X-d)<sqrabs(d_-d) then d_:=X;
    if sqrabs(X-a)<sqrabs(a_-a) then a_:=X;

    addFlatQuad(a_,b_,c_,d_,color);
    addFlatQuad(a,b,b_,a_,colorOfSide(a,b,color));
    addFlatQuad(b,c,c_,b_,colorOfSide(c,d,color));
    addFlatQuad(c,d,d_,c_,colorOfSide(c,d,color));
    addFlatQuad(d,a,a_,d_,colorOfSide(d,a,color));
  end;

PROCEDURE T_tileBuilder.addHexagon(CONST a, b, c, d,e,f: T_Complex; CONST color: T_rgbFloatColor);
  VAR ab_shifted,
      bc_shifted,
      cd_shifted,
      de_shifted,
      ef_shifted,
      fa_shifted:T_complexPair;
      a_,b_,c_,d_,e_,f_,X:T_Complex;
  begin
    if flat then begin
      addFlatQuad(a,b,c,d,color);
      addFlatQuad(d,e,f,a,color);
      exit;
    end;
    ab_shifted:=shiftEdge(a,b);
    bc_shifted:=shiftEdge(b,c);
    cd_shifted:=shiftEdge(c,d);
    de_shifted:=shiftEdge(d,e);
    ef_shifted:=shiftEdge(e,f);
    fa_shifted:=shiftEdge(f,a);
    a_:=edgeCut(fa_shifted,ab_shifted);
    b_:=edgeCut(ab_shifted,bc_shifted);
    c_:=edgeCut(bc_shifted,cd_shifted);
    d_:=edgeCut(cd_shifted,de_shifted);
    e_:=edgeCut(de_shifted,ef_shifted);
    f_:=edgeCut(ef_shifted,fa_shifted);

    X:=edgeCut(a,a_,b,b_);
    if sqrabs(X-a)<sqrabs(a_-a) then a_:=X;
    if sqrabs(X-b)<sqrabs(b_-b) then b_:=X;
    X:=edgeCut(b,b_,c,c_);
    if sqrabs(X-b)<sqrabs(b_-b) then b_:=X;
    if sqrabs(X-c)<sqrabs(c_-c) then c_:=X;
    X:=edgeCut(c,c_,d,d_);
    if sqrabs(X-c)<sqrabs(c_-c) then c_:=X;
    if sqrabs(X-d)<sqrabs(d_-d) then d_:=X;
    X:=edgeCut(d,d_,e,e_);
    if sqrabs(X-d)<sqrabs(d_-d) then d_:=X;
    if sqrabs(X-e)<sqrabs(e_-e) then e_:=X;
    X:=edgeCut(e,e_,f,f_);
    if sqrabs(X-e)<sqrabs(e_-e) then e_:=X;
    if sqrabs(X-f)<sqrabs(f_-f) then f_:=X;
    X:=edgeCut(f,f_,a,a_);
    if sqrabs(X-f)<sqrabs(f_-f) then f_:=X;
    if sqrabs(X-a)<sqrabs(a_-a) then a_:=X;

    addFlatQuad(a_,b_,c_,d_,color);
    addFlatQuad(d_,e_,f_,a_,color);
    addFlatQuad(a,b,b_,a_,colorOfSide(a,b,color));
    addFlatQuad(b,c,c_,b_,colorOfSide(b,c,color));
    addFlatQuad(c,d,d_,c_,colorOfSide(c,d,color));
    addFlatQuad(d,e,e_,d_,colorOfSide(d,e,color));
    addFlatQuad(e,f,f_,e_,colorOfSide(e,f,color));
    addFlatQuad(f,a,a_,f_,colorOfSide(f,a,color));
  end;

TYPE T_triangleInfo=record
  base:T_quad;
  variance:double;
end;

FUNCTION scanTriangle(VAR triangleInfo:T_triangleInfo; CONST imgBB:T_boundingBox; VAR image:T_rawImage):longint;
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
      c:=image[x,y];
      k +=1;
      s +=c;
      ss+=c*c;
    end;
    ss-=s*s*(1/k);
    triangleInfo.base.color:=s*(1/k);
    result:=k;
    if k=0
    then triangleInfo.variance:=-1
    else triangleInfo.variance:=(ss[cc_red]+ss[cc_green]+ss[cc_blue]);
  end;

PROCEDURE T_tileBuilder.addTriangle(CONST a, b, c: T_Complex);
  VAR info:T_triangleInfo;
  begin
    with info.base do begin
      p0:=a; p1:=b; p2:=c; p3:=a; isTriangle:=true;
    end;
    scanTriangle(info,imageBoundingBox,context^.image);
    addTriangle(a,b,c,info.base.color);
  end;

PROCEDURE T_tileBuilder.addQuad(CONST a, b, c, d: T_Complex);
  VAR info:T_triangleInfo;
  begin
    with info.base do begin
      p0:=a; p1:=b; p2:=c; p3:=d; isTriangle:=false;
    end;
    scanTriangle(info,imageBoundingBox,context^.image);
    addQuad(a,b,c,d,info.base.color);
  end;

PROCEDURE T_tileBuilder.addHexagon(CONST a, b, c, d,e,f: T_Complex);
  VAR half1,half2:T_triangleInfo;
      w1,w2:longint;
  begin
    with half1.base do begin p0:=a; p1:=b; p2:=c; p3:=d; isTriangle:=false; end;
    with half2.base do begin p0:=d; p1:=e; p2:=f; p3:=a; isTriangle:=false; end;
    w1:=scanTriangle(half1,imageBoundingBox,context^.image);
    w2:=scanTriangle(half2,imageBoundingBox,context^.image);
    addHexagon(a,b,c,d,e,f,
               (half1.base.color*w1 +
                half2.base.color*w2)*(1/max(w1+w1,1)));
  end;

PROCEDURE T_tileBuilder.startExecution;
  VAR todo:P_trianglesTodo;
      i:longint;
  begin
    setLength(drawable,drawableCount);
    context^.clearQueue;
    context^.image.markChunksAsPending;
    for i in context^.image.getPendingList do begin
      new(todo,create(drawable,i,@(context^.image)));
      context^.enqueue(todo);
    end;
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
  VAR prevHit:array[0..CHUNK_BLOCK_SIZE-1,0..CHUNK_BLOCK_SIZE-1] of longint;
  FUNCTION getColorAt(CONST i,j:longint; CONST x,y:double):T_rgbFloatColor; inline;
    VAR k:longint;
    begin
      k:=prevHit[i,j];
      if isInside(x,y,quadsInRange[k]) then exit(quadsInRange[k].color);
      for k:=0 to length(quadsInRange)-1 do if isInside(x,y,quadsInRange[k]) then begin
        prevHit[i,j]:=k;
        exit(quadsInRange[k].color);
      end;
      result:=BLACK;
    end;

  VAR chunk:T_colChunk;
      i,j,k,k0,k1:longint;
  begin
    chunk.create;
    chunk.initForChunk(containedIn^.image.dimensions.width,containedIn^.image.dimensions.height,chunkIndex);
    for i:=0 to CHUNK_BLOCK_SIZE-1 do for j:=0 to CHUNK_BLOCK_SIZE-1 do prevHit[i,j]:=0;
    for i:=0 to chunk.width-1 do for j:=0 to chunk.height-1 do with chunk.col[i,j] do rest:=getColorAt(i,j,chunk.getPicX(i),chunk.getPicY(j));
    if not(containedIn^.previewQuality) then
    while chunk.markAlias(0.1) and not(containedIn^.cancellationRequested) do
    for i:=0 to chunk.width-1 do for j:=0 to chunk.height-1 do with chunk.col[i,j] do if odd(antialiasingMask) then begin
      if antialiasingMask=1 then begin
        k0:=1; k1:=2; antialiasingMask:=2; k1:=2*k1;
      end else begin
        k0:=antialiasingMask-1;
        k1:=k0+2;
        if k1>254 then k1:=254;
        antialiasingMask:=k1;
        k0:=2*k0; k1:=2*k1;
      end;
      for k:=k0 to k1-1 do rest:=rest+getColorAt(i,j,
        chunk.getPicX(i)+darts_delta[k,0],
        chunk.getPicY(j)+darts_delta[k,1]);
    end;
    containedIn^.image.copyFromChunk(chunk);
    chunk.destroy;
  end;

FUNCTION findApproximatingTriangles(CONST context:P_abstractWorkflow; CONST count:longint; CONST style:byte):T_quadList;
  VAR imgBB:T_boundingBox;
  VAR tri:array of T_triangleInfo;
  PROCEDURE initTriangles;
    CONST c=0.5;
          s=0.8660254037844388;
    VAR a:double;
        p0,p1,p2:T_Complex;
    begin
      a:=max(context^.image.dimensions.width/2/s*1.5+context^.image.dimensions.height/2,context^.image.dimensions.height);
      p0.re:=context^.image.dimensions.width /2;
      p0.im:=context^.image.dimensions.height/2;
      p1:=a*( s+II*c)+p0;
      p2:=a*(-s+II*c)+p0;
      p0-=a*II;
      setLength(tri,1);
      with tri[0] do begin
        base.p0:=p0;
        base.p1:=p1;
        base.p2:=p2;
        base.p3:=p0;
        base.isTriangle:=true;
        base.color:=BLACK;
        variance:=1;
      end;
    end;

  PROCEDURE splitTriangles;
    VAR toSplit:longint=0;
        i:longint;
        edgeToSplit:byte=0;
        l,l2:double;
        a0,a1,b0,b1,c0,c1:T_triangleInfo;
    begin
      for i:=1 to length(tri)-1 do if tri[i].variance>tri[toSplit].variance then toSplit:=i;
      with tri[toSplit] do begin
        l:= sqrabs(base.p1-base.p0);
        l2:=sqrabs(base.p2-base.p1);
        if l2>l then begin l:=l2; edgeToSplit:=1; end;
        l2:=sqrabs(base.p0-base.p2);
        if l2>l then              edgeToSplit:=2;
      end;
      a0:=tri[toSplit];
      a1:=tri[toSplit];
      b0:=tri[toSplit];
      b1:=tri[toSplit];
      c0:=tri[toSplit];
      c1:=tri[toSplit];
      case style of
        1: begin
          b1.base.p0:=(a0.base.p0+a0.base.p1)*0.5;
          b1.base.p1:=(a0.base.p1+a0.base.p2)*0.5;
          b1.base.p2:=(a0.base.p2+a0.base.p0)*0.5; b1.base.p0:=b1.base.p0;
          a1.base.p1:=b1.base.p0;
          a1.base.p2:=b1.base.p2;
          b0.base.p0:=b1.base.p0;
          b0.base.p2:=b1.base.p1;
          a0.base.p0:=b1.base.p2;
          a0.base.p1:=b1.base.p1;
          scanTriangle(a0,imgBB,context^.image);
          scanTriangle(a1,imgBB,context^.image);
          scanTriangle(b0,imgBB,context^.image);
          scanTriangle(b1,imgBB,context^.image);
          i:=length(tri);
          setLength(tri,i+3);
          tri[toSplit]:=a0;
          tri[i  ]:=a1;
          tri[i+1]:=b0;
          tri[i+2]:=b1;
        end;
        2: begin
          case edgeToSplit of
            0: begin
              a0.base.p1:=a0.base.p0*0.5 +a0.base.p1*0.5 ; a1.base.p0:=a0.base.p1;
              b0.base.p1:=b0.base.p0*0.33+b0.base.p1*0.67; b1.base.p0:=b0.base.p1;
              c0.base.p1:=c0.base.p0*0.67+c0.base.p1*0.33; c1.base.p0:=c0.base.p1;
            end;
            1: begin
              a0.base.p2:=a0.base.p1*0.5 +a0.base.p2*0.5 ; a1.base.p1:=a0.base.p2; a0.base.p3:=a0.base.p2;
              b0.base.p2:=b0.base.p1*0.33+b0.base.p2*0.67; b1.base.p1:=b0.base.p2; b0.base.p3:=b0.base.p2;
              c0.base.p2:=c0.base.p1*0.67+c0.base.p2*0.33; c1.base.p1:=c0.base.p2; c0.base.p3:=c0.base.p2;
            end;
            2: begin
              a0.base.p2:=a0.base.p2*0.5 +a0.base.p0*0.5 ; a1.base.p0:=a0.base.p2; a0.base.p3:=a0.base.p2;
              b0.base.p2:=b0.base.p2*0.33+b0.base.p0*0.67; b1.base.p0:=b0.base.p2; b0.base.p3:=b0.base.p2;
              c0.base.p2:=c0.base.p2*0.67+c0.base.p0*0.33; c1.base.p0:=c0.base.p2; c0.base.p3:=c0.base.p2;
            end;
          end;
          scanTriangle(a0,imgBB,context^.image); scanTriangle(a1,imgBB,context^.image);
          scanTriangle(b0,imgBB,context^.image); scanTriangle(b1,imgBB,context^.image);
          scanTriangle(c0,imgBB,context^.image); scanTriangle(c1,imgBB,context^.image);
          if b0.variance+b1.variance<a0.variance+a1.variance then begin a0:=b0; a1:=b1; end;
          if c0.variance+c1.variance<a0.variance+a1.variance then begin a0:=c0; a1:=c1; end;
          i:=length(tri);
          setLength(tri,i+1);
          tri[toSplit]:=a0;
          tri[i      ]:=a1;
        end
        else begin
          case edgeToSplit of
            0: begin
              a0.base.p1:=a0.base.p0*0.5 +a0.base.p1*0.5 ; a1.base.p0:=a0.base.p1;
            end;
            1: begin
              a0.base.p2:=a0.base.p1*0.5 +a0.base.p2*0.5 ; a1.base.p1:=a0.base.p2;
            end;
            2: begin
              a0.base.p2:=a0.base.p2*0.5 +a0.base.p0*0.5 ; a1.base.p0:=a0.base.p2;
            end;
          end;
          scanTriangle(a0,imgBB,context^.image); scanTriangle(a1,imgBB,context^.image);
          i:=length(tri);
          setLength(tri,i+1);
          tri[toSplit]:=a0;
          tri[i      ]:=a1;
        end;
      end;
    end;

  VAR i:longint;
  begin
    imgBB.x0:=0;
    imgBB.y0:=0;
    imgBB.x1:=context^.image.dimensions.width;
    imgBB.y1:=context^.image.dimensions.height;
    initialize(tri);
    initTriangles;
    while (length(tri)<count) and not(context^.cancellationRequested) do splitTriangles;
    setLength(result,length(tri));
    for i:=0 to length(result)-1 do result[i]:=tri[i].base;
    setLength(tri,0);
  end;

PROCEDURE triangleSplit(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  VAR rawTriangles:T_quadList;
      builder:T_tileBuilder;
      i:longint;
  begin
    rawTriangles:=findApproximatingTriangles(context,parameters.i0,parameters.i1);
    builder.create(context,parameters.f2,parameters.f3);
    for i:=0 to length(rawTriangles)-1 do builder.addTriangle(rawTriangles[i]);
    setLength(rawTriangles,0);
    builder.startExecution;
    context^.waitForFinishOfParallelTasks;
    builder.destroy;
  end;

PROCEDURE spheres_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  FUNCTION triangleToCircle(CONST tri:T_quad):T_circle;
    VAR a,b,c,d:double;
        u,v,w:T_Complex;
    begin
      u:=tri.p0;
      v:=tri.p1;
      w:=tri.p2;
      A:=u.re*(v.im-w.im)-u.im*(v.re-w.re)+v.re*w.im-w.re*v.im;
      B:=sqrabs(u)*(w.im-v.im)+sqrabs(v)*(u.im-w.im)+sqrabs(w)*(v.im-u.im);
      C:=sqrabs(u)*(v.re-w.re)+sqrabs(v)*(w.re-u.re)+sqrabs(w)*(u.re-v.re);
      D:=sqrabs(u)*(w.re*v.im-v.re*w.im)+
         sqrabs(v)*(u.re*w.im-w.re*u.im)+
         sqrabs(w)*(v.re*u.im-u.re*v.im);
      result.center.re:=B/(-2*A);
      result.center.im:=C/(-2*A);
      result.radius:=sqrt((B*B+C*C-4*A*D))/abs(2*A);
      result.color:=tri.color;
      if hasNanOrInfiniteComponent(result.color) then result.radius:=0;
    end;

  CONST TODO_MODE:array[0..4] of T_sphereTodoMode=(stm_overlappingCircles,stm_overlappingMatteSpheres,stm_overlappingShinySpheres,stm_overlappingMatteSpheres,stm_overlappingBorderedCircles);
  VAR rawTriangles:T_quadList;
      circles:T_circles;
      i,j:longint;
      tmp:T_circle;
      todo:P_spheresTodo;

  begin
    rawTriangles:=findApproximatingTriangles(context,parameters.i0,2);
    if parameters.i1=3 then //White matte spheres
      for i:=0 to length(rawTriangles)-1 do rawTriangles[i].color:=WHITE;
    setLength(circles,length(rawTriangles));
    for i:=0 to length(circles)-1 do begin
      circles[i]:=triangleToCircle(rawTriangles[i]);
      j:=i;
      while (j>0) and (circles[j-1].radius>circles[j].radius) do begin
        tmp         :=circles[j  ];
        circles[j  ]:=circles[j-1];
        circles[j-1]:=tmp;
        dec(j);
      end;
    end;
    setLength(rawTriangles,0);
    with context^ do begin
      clearQueue;
      image.markChunksAsPending;
      for i:=0 to image.chunksInMap-1 do begin
        new(todo,create(circles,TODO_MODE[parameters.i1],i,@image));
        enqueue(todo);
      end;
      setLength(circles,0);
      waitForFinishOfParallelTasks;
    end;
  end;

INITIALIZATION
registerSimpleOperation(imc_misc,
  newParameterDescription('triangleSplit',pt_2I2F)^
    .setDefaultValue('500,0,1,20')^
    .addChildParameterDescription(spa_i0,'count',pt_integer,2,200000)^
    .addEnumChildDescription(spa_i1,'split','half-split','quarter-split','half adaptive')^
    .addChildParameterDescription(spa_f2,'border width',pt_float,0)^
    .addChildParameterDescription(spa_f3,'border angle',pt_float,0,90),
  @triangleSplit);
registerSimpleOperation(imc_misc,
  newParameterDescription('spheres',pt_2integers,0)^
    .setDefaultValue('2000,1')^
    .addChildParameterDescription(spa_i0,'sphere count',pt_integer,1,100000)^
    .addEnumChildDescription(spa_i1,'style','circles','matte spheres','shiny spheres','white spheres','embossed circles'),
  @spheres_impl);

end.

