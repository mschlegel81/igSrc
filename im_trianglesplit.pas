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

  T_complexPair=array[0..1] of T_Complex;
  T_tileBuilder=object
    private
      drawable        :T_quadList;
      drawableCount   :longint;
      imageBoundingBox:T_boundingBox;
      areaEpsilon     :double;
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
      PROCEDURE addTriangle(CONST a,b,c      :T_Complex; color:T_rgbFloatColor; CONST scanColor:boolean=false);
      PROCEDURE addQuad    (CONST a,b,c,d    :T_Complex; color:T_rgbFloatColor; CONST scanColor:boolean=false);
      PROCEDURE addHexagon (CONST a,b,c,d,e,f:T_Complex; color:T_rgbFloatColor; CONST scanColor:boolean=false);

      PROCEDURE execute(CONST doClear:boolean; CONST clearColor:T_rgbFloatColor);
  end;

FUNCTION crossProduct(CONST a,b:T_Complex; CONST x2,y2:double):double; inline;
FUNCTION findApproximatingTriangles(CONST context:P_abstractWorkflow; CONST count:longint; CONST style:byte; CONST scaler:T_scaler):T_quadList;
IMPLEMENTATION
USES imageManipulation,myParams,mypics,math,pixMaps,darts,ig_circlespirals,sysutils;
TYPE T_pixelCoordinate=record ix,iy:longint; end;
     T_pixelCoordinates=array of T_pixelCoordinate;

FUNCTION getBoundingBox(CONST q:T_quad):T_boundingBox;
  begin
    result.x0:=min(q.p0.re,min(q.p1.re,min(q.p2.re,q.p3.re)));
    result.y0:=min(q.p0.im,min(q.p1.im,min(q.p2.im,q.p3.im)));
    result.x1:=max(q.p0.re,max(q.p1.re,max(q.p2.re,q.p3.re)));
    result.y1:=max(q.p0.im,max(q.p1.im,max(q.p2.im,q.p3.im)));
  end;

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

FUNCTION getPixelCoordinates(CONST q:T_quad; CONST box:T_boundingBox; CONST deltaX:double=0; CONST deltaY:double=0):T_pixelCoordinates;
  VAR a,b:array[0..2] of T_Complex;
      tmp:T_Complex;
      i,j:longint;
      resCount:longint=0;

      jab,ja0,ja1,jb0,jb1,jboth:longint;
      xa0,xa1,dxa0,dxa1,
      xb0,xb1,dxb0,dxb1:double;
  begin
    //given a quad (p0,p1,p2,p3) we consider
    //triangles (p0,p1,p2) and (p0,p3,p2)
    tmp:=q.p0; i:=0;
    if q.p1.im<tmp.im then begin i:=1; tmp:=q.p1; end;
    if q.p2.im<tmp.im then begin i:=2; tmp:=q.p2; end;
    if q.p3.im<tmp.im then begin i:=3; tmp:=q.p3; end;
    tmp.re:=deltaX;
    tmp.im:=deltaY;
    //choose triangles so that they have their min-point in common
    if (i=0) or (i=2) then begin
      a[0]:=q.p0+tmp; a[1]:=q.p1+tmp; a[2]:=q.p2+tmp;
      b[0]:=q.p0+tmp; b[1]:=q.p2+tmp; b[2]:=q.p3+tmp;
    end else begin
      a[0]:=q.p1+tmp; a[1]:=q.p2+tmp; a[2]:=q.p3+tmp;
      b[0]:=q.p1+tmp; b[1]:=q.p3+tmp; b[2]:=q.p0+tmp;
    end;
    //sort triangles a and b by y-coordinate
    for i:=1 to 2 do for j:=0 to i-1 do begin
      if a[i].im<a[j].im then begin tmp:=a[i]; a[i]:=a[j]; a[j]:=tmp; end;
      if b[i].im<b[j].im then begin tmp:=b[i]; b[i]:=b[j]; b[j]:=tmp; end;
    end;
    jab:=round(a[0].im);
    ja0:=round(a[1].im); jb0:=round(b[1].im);
    ja1:=round(a[2].im); jb1:=round(b[2].im);
    if ja1<jb1 then jboth:=ja1 else jboth:=jb1;
    initialize(result);
    setLength(result,100);
    xa0:=a[0].re; dxa0:=(a[1].re-a[0].re)/(a[1].im-a[0].im);
    xa1:=a[0].re; dxa1:=(a[2].re-a[0].re)/(a[2].im-a[0].im);
    xb0:=b[0].re; dxb0:=(b[1].re-b[0].re)/(b[1].im-b[0].im);
    xb1:=b[0].re; dxb1:=(b[2].re-b[0].re)/(b[2].im-b[0].im);
    //iterate over shared y-range
    for j:=jab to jboth do begin
      if j=ja0 then begin xa0:=a[1].re; dxa0:=(a[2].re-a[1].re)/(a[2].im-a[1].im); end;
      if j=jb0 then begin xb0:=b[1].re; dxb0:=(b[2].re-b[1].re)/(b[2].im-b[1].im); end;
      if (j>=box.y0) and (j<box.y1) then for i:=round(max(box.x0,min(min(xa0,xb0),min(xa1,xb1)))) to
                                                round(min(box.x1,max(max(xa0,xb0),max(xa1,xb1)))) do begin
        if resCount>=length(result) then setLength(result,resCount*2);
        result[resCount].ix:=i;
        result[resCount].iy:=j;
        inc(resCount);
      end;
      xa0+=dxa0;
      xa1+=dxa1;
      xb0+=dxb0;
      xb1+=dxb1;
    end;
    //iterate over a-only
    for j:=jboth+1 to min(ja1,round(box.y1)-1) do begin
      if (j>=box.y0) and (j<box.y1) then for i:=round(max(box.x0,min(xa0,xa1))) to
                                                round(min(box.x1,max(xa0,xa1))) do begin
        if resCount>=length(result) then setLength(result,resCount*2);
        result[resCount].ix:=i;
        result[resCount].iy:=j;
        inc(resCount);
      end;
      xa0+=dxa0;
      xa1+=dxa1;
    end;
    //iterate over b-only
    for j:=jboth+1 to min(jb1,round(box.y1)-1) do begin
      if (j>=box.y0) and (j<box.y1) then for i:=round(max(box.x0,min(xb0,xb1))) to
                                                round(min(box.x1,max(xb0,xb1))) do begin
        if resCount>=length(result) then setLength(result,resCount*2);
        result[resCount].ix:=i;
        result[resCount].iy:=j;
        inc(resCount);
      end;
      xb0+=dxb0;
      xb1+=dxb1;
    end;
    setLength(result,resCount);
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

{Use this only for pixel coordinates. Otherwise the epsilon is too large.}
FUNCTION almostEqual(CONST a,b:T_Complex):boolean; inline;
  begin result:=(abs(a.re-b.re)<1E-3) and (abs(a.im-b.im)<1E-3); end;

FUNCTION isHorizontalEdgeCut(y,x0,x1:double; CONST a,b:T_Complex):boolean;
  VAR t:double;
  begin
    // y = a.im+t*(b.im-a.im);
    // y-a.im = t*(b.im-a.im);
    // (y-a.im)  /(b.im-a.im) = t
    t:=(y-a.im)/(b.im-a.im);
    if (t>=0) and (t<=1) then begin
      t:=a.re+t*(b.re-a.re);
      result:=(t>=x0) and (t<=x1);
    end else result:=false;
  end;

FUNCTION isVerticalEdgeCut(x,y0,y1:double; CONST a,b:T_Complex):boolean;
  VAR t:double;
  begin
    t:=(x-a.re)/(b.re-a.re);
    if (t>=0) and (t<=1) then begin
      t:=a.im+t*(b.im-a.im);
      result:=(t>=y0) and (t<=y1);
    end else result:=false;
  end;

FUNCTION CohenSutherland_LineVisible(a,b:T_Complex; CONST box:T_boundingBox):boolean; //returns true if line visible
  CONST
    INSIDE = 0; // 0000
    Left   = 1; // 0001
    Right  = 2; // 0010
    Bottom = 4; // 0100
    top    = 8; // 1000
  FUNCTION ComputeOutCode(CONST p:T_Complex):byte;
    begin
      if      (p.re < box.x0) then result := Left
      else if (p.re > box.x1) then result := Right
      else result:=INSIDE;
      if      (p.im < box.y0) then result += Bottom
      else if (p.im > box.y1) then result += top;
    end;

  VAR outcode0,outcode1,outcodeOut:integer;
      x,y:double;
  begin
    // compute outcodes for P0, P1, and whatever point lies outside the clip rectangle
    outcode0 := ComputeOutCode(a);
    outcode1 := ComputeOutCode(b);
    x:=0; y:=0;
    while (true) do begin
      if (outcode0 or outcode1 = 0 ) then begin
        exit(true);
        break;
      end else if (outcode0 and outcode1<>0) then exit(false)
      else begin
        if (outcode0 <> 0) then outcodeOut:=outcode0
          else outcodeOut:=outcode1;     //outcodeOut = outcode0 ? outcode0 : outcode1;
        if (outcodeOut and top <>0 ) then           // point is above the clip rectangle
          begin
            x := a.re + (b.re - a.re) * (box.y1 - a.im) / (b.im - a.im);
            y := box.y1;
          end
        else if (outcodeOut and Bottom <>0) then  // point is below the clip rectangle
          begin
            x := a.re + (b.re - a.re) * (box.y0 - a.im) / (b.im - a.im);
            y := box.y0;
          end
        else if (outcodeOut and Right <>0) then  // point is to the right of clip rectangle
          begin
            y := a.im + (b.im - a.im) * (box.x1 - a.re) / (b.re - a.re);
            x := box.x1;
          end
        else // point is to the left of clip rectangle
          begin
            y := a.im + (b.im - a.im) * (box.x0 - a.re) / (b.re - a.re);
            x := box.x0;
          end;

        (* NOTE:if you follow this algorithm exactly(at least for c#), then you will fall into an infinite loop
        in case a line crosses more than two segments. to avoid that problem, leave OUT the last else
        if(outcodeOut & Left) and just make it else *)

        // Now we move outside point to intersection point to clip
        // and get ready for next pass.
        if (outcodeOut = outcode0) then
          begin
            a.re := x;
            a.im := y;
            outcode0 := ComputeOutCode(a);
          end
          else begin
            b.re := x;
            b.im := y;
            outcode1 := ComputeOutCode(b);
          end;
      end;
    end;
  end;

FUNCTION quadIsInBoundingBox(CONST q:T_quad; CONST box:T_boundingBox):boolean;
  begin
    if (q.p0.re>=box.x0) and (q.p0.re<=box.x1) and (q.p0.im>=box.y0) and (q.p0.im<=box.y1) or
       (q.p1.re>=box.x0) and (q.p1.re<=box.x1) and (q.p1.im>=box.y0) and (q.p1.im<=box.y1) or
       (q.p2.re>=box.x0) and (q.p2.re<=box.x1) and (q.p2.im>=box.y0) and (q.p2.im<=box.y1) or
       (q.p3.re>=box.x0) and (q.p3.re<=box.x1) and (q.p3.im>=box.y0) and (q.p3.im<=box.y1) or
       isInside(box.x0,box.y0,q) or
       isInside(box.x1,box.y0,q) or
       isInside(box.x0,box.y1,q) or
       isInside(box.x1,box.y1,q) then exit(true);
    if q.isTriangle then begin
      result:=CohenSutherland_LineVisible(q.p0,q.p1,box) or
              CohenSutherland_LineVisible(q.p1,q.p2,box) or
              CohenSutherland_LineVisible(q.p2,q.p0,box);
    end else begin
      result:=CohenSutherland_LineVisible(q.p0,q.p1,box) or
              CohenSutherland_LineVisible(q.p2,q.p3,box) or
              CohenSutherland_LineVisible(q.p1,q.p2,box) or
              CohenSutherland_LineVisible(q.p3,q.p0,box);
    end;
  end;

TYPE
P_trianglesTodo=^T_trianglesTodo;
T_trianglesTodo=object(T_parallelTask)
  chunkIndex:longint;
  quadsInRange:T_quadList;
  box:T_boundingBox;

  CONSTRUCTOR create(CONST chunkIndex_:longint;
                     CONST target_:P_rawImage);
  PROCEDURE addQuad(CONST quad:T_quad);
  DESTRUCTOR destroy; virtual;
  PROCEDURE execute; virtual;
end;

PROCEDURE T_tileBuilder.addFlatTriangle(CONST a, b, c: T_Complex;
  CONST color: T_rgbFloatColor);
  begin
    //Only add triangles if orientation fits and the area is larger than epsilon
    if crossProduct(a,b,c.re,c.im)<areaEpsilon then exit;
    addFlatQuad(a,b,c,a,color);
  end;

PROCEDURE T_tileBuilder.addFlatQuad(CONST a, b, c, d: T_Complex;
  CONST color: T_rgbFloatColor);
  begin
    //Only add triangles if orientation fits and the area is larger than epsilon
    if crossProduct(a,b,c.re,c.im)+crossProduct(c,d,a.re,a.im)<areaEpsilon then exit;
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
    if quadIsInBoundingBox(drawable[drawableCount],imageBoundingBox) then inc(drawableCount);
  end;

CONSTRUCTOR T_tileBuilder.create(CONST workflow: P_abstractWorkflow;
  CONST relativeBorderWidth, borderAngleInDegrees: double);
  begin
    setLength(drawable,1);
    drawableCount:=0;
    context:=workflow;
    BorderWidth:=relativeBorderWidth/1000*context^.image.diagonal;
    borderUpFraction    :=system.cos(borderAngleInDegrees*0.017453292519943295);
    borderAcrossFraction:=system.sin(borderAngleInDegrees*0.017453292519943295);
    flat:=(BorderWidth<0.01) or (borderAcrossFraction<0.01);
    imageBoundingBox.x0:=0;
    imageBoundingBox.y0:=0;
    imageBoundingBox.x1:=context^.image.dimensions.width;
    imageBoundingBox.y1:=context^.image.dimensions.height;
    if workflow^.previewQuality then areaEpsilon:=10 else areaEpsilon:=0.1;
  end;

DESTRUCTOR T_tileBuilder.destroy;
  begin
    setLength(drawable,0);
  end;

PROCEDURE T_tileBuilder.addTriangle(CONST q: T_quad);
  begin
    addTriangle(q.p0,q.p1,q.p2,q.color,false);
  end;

FUNCTION T_tileBuilder.shiftEdge(CONST a, b: T_Complex): T_complexPair;
  VAR d:T_Complex;
  begin
    d.re:=a.im-b.im;
    d.im:=b.re-a.re;
    d*=BorderWidth/abs(d);
    result[0]:=a+d;
    result[1]:=b+d;
  end;

FUNCTION T_tileBuilder.colorOfSide(CONST a, b: T_Complex;
  CONST baseColor: T_rgbFloatColor): T_rgbFloatColor;
  VAR d:T_Complex;
  begin
    d:=a-b;
    d:=d*II/complex.abs(d);
    result:=simpleIlluminatedColor(baseColor,borderAcrossFraction*d.re,
                                             borderAcrossFraction*d.im,
                                             borderUpFraction);
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
    if (box.x1>=box.x0) and (box.y1>box.y0) then
    for y:=floor(box.y0) to ceil(box.y1)-1 do
    for x:=floor(box.x0) to ceil(box.x1)-1 do
    if isInside(x,y,triangleInfo.base) then begin
      c:=image[x,y];
      k +=1;
      s +=c;
      ss+=c*c;
    end;
    ss-=s*s*(1/k);
    if k=0 then begin
      triangleInfo.variance:=0;
      x:=round(max(imgBB.x0,min(imgBB.x1, (triangleInfo.base.p0.re+triangleInfo.base.p1.re+triangleInfo.base.p2.re)/3)));
      y:=round(max(imgBB.y0,min(imgBB.y1, (triangleInfo.base.p0.im+triangleInfo.base.p1.im+triangleInfo.base.p2.im)/3)));
      triangleInfo.base.color:=image.pixel[x,y];
      result:=0;
    end else begin
      triangleInfo.variance:=(ss[cc_red]+ss[cc_green]+ss[cc_blue]);
      triangleInfo.base.color:=s*(1/k);
      result:=k;
    end;
  end;

PROCEDURE T_tileBuilder.addTriangle(CONST a, b, c: T_Complex; color: T_rgbFloatColor; CONST scanColor: boolean);
  VAR info:T_triangleInfo;
      ab_shifted,
      bc_shifted,
      ca_shifted:T_complexPair;
      a_,b_,c_,X:T_Complex;
  begin
    if almostEqual(a,b) or almostEqual(b,c) or almostEqual(c,a) or allOutside(imageBoundingBox,a,b,c) then exit;
    if scanColor then begin
      with info.base do begin
        p0:=a; p1:=b; p2:=c; p3:=a; isTriangle:=true;
      end;
      scanTriangle(info,imageBoundingBox,context^.image);
      color:=info.base.color;
    end;
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

PROCEDURE T_tileBuilder.addQuad(CONST a, b, c, d: T_Complex; color: T_rgbFloatColor; CONST scanColor: boolean);
  VAR ab_shifted,
      bc_shifted,
      cd_shifted,
      da_shifted:T_complexPair;
      a_,b_,c_,d_,X:T_Complex;
      info:T_triangleInfo;
  begin
    if (crossProduct(a,b,c.re,c.im)+crossProduct(b,c,d.re,d.im)<areaEpsilon) or allOutside(imageBoundingBox,a,b,c,d) then exit;
    if scanColor then begin
      with info.base do begin
        p0:=a; p1:=b; p2:=c; p3:=d; isTriangle:=false;
      end;
      scanTriangle(info,imageBoundingBox,context^.image);
      color:=info.base.color;
    end;
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
    addFlatQuad(b,c,c_,b_,colorOfSide(b,c,color));
    addFlatQuad(c,d,d_,c_,colorOfSide(c,d,color));
    addFlatQuad(d,a,a_,d_,colorOfSide(d,a,color));
  end;

PROCEDURE T_tileBuilder.addHexagon(CONST a, b, c, d, e, f: T_Complex;
  color: T_rgbFloatColor; CONST scanColor: boolean);
  VAR ab_shifted,
      bc_shifted,
      cd_shifted,
      de_shifted,
      ef_shifted,
      fa_shifted:T_complexPair;
      a_,b_,c_,d_,e_,f_,X:T_Complex;
  VAR half1,half2:T_triangleInfo;
      w1,w2:longint;

  begin
    if (crossProduct(a,b,c.re,c.im)+
        crossProduct(c,d,e.re,e.im)+
        crossProduct(e,f,a.re,a.im)+
        crossProduct(c,e,a.re,a.im)<areaEpsilon) or allOutside(imageBoundingBox,a,b,c,d,e,f) then exit;
    if scanColor then begin
      with half1.base do begin p0:=a; p1:=b; p2:=c; p3:=d; isTriangle:=false; end;
      with half2.base do begin p0:=d; p1:=e; p2:=f; p3:=a; isTriangle:=false; end;
      w1:=scanTriangle(half1,imageBoundingBox,context^.image);
      w2:=scanTriangle(half2,imageBoundingBox,context^.image);
      color:=(half1.base.color*w1 +
              half2.base.color*w2)*(1/max(w1+w2,1));
    end;
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

PROCEDURE T_tileBuilder.execute(CONST doClear:boolean; CONST clearColor:T_rgbFloatColor);
  VAR
      todos:array of P_trianglesTodo;
      quad:T_quad;
      quadBB:T_boundingBox;
      i,j:longint;
      i0,i1,j0,j1:longint;
      xChunkCount:longint;
      yChunkCount:longint;

      baseFraction :double=1;
      whiteFraction:double=0;
      Pixels:P_floatColor;
  begin
    if not(flat) then averageIllumination(borderAcrossFraction,borderUpFraction,baseFraction,whiteFraction);
    setLength(drawable,drawableCount);
    if doClear then context^.image.clearWithColor(clearColor*baseFraction+WHITE*whiteFraction)
    else if not(flat) then begin
      Pixels:=context^.image.rawData;
      for i:=0 to context^.image.pixelCount-1 do Pixels[i]:=Pixels[i]*baseFraction+WHITE*whiteFraction;
    end;
    if drawableCount>0 then begin
      context^.clearQueue;
      xChunkCount:=context^.image.dimensions.width  div CHUNK_BLOCK_SIZE; if xChunkCount*CHUNK_BLOCK_SIZE<context^.image.dimensions.width  then inc(xChunkCount);
      yChunkCount:=context^.image.dimensions.height div CHUNK_BLOCK_SIZE; if yChunkCount*CHUNK_BLOCK_SIZE<context^.image.dimensions.height then inc(yChunkCount);
      setLength(todos,context^.image.chunksInMap);
      for i:=0 to length(todos)-1 do new(todos[i],create(i,@(context^.image)));
      for quad in drawable do begin
        quadBB:=getBoundingBox(quad);
        i0:=max(0            ,floor(quadBB.x0/CHUNK_BLOCK_SIZE));
        i1:=min(xChunkCount-1,ceil (quadBB.x1/CHUNK_BLOCK_SIZE));
        j0:=max(0            ,floor(quadBB.y0/CHUNK_BLOCK_SIZE));
        j1:=min(yChunkCount-1,ceil (quadBB.y1/CHUNK_BLOCK_SIZE));
        for j:=j0 to j1 do for i:=i0 to i1 do todos[i+j*xChunkCount]^.addQuad(quad);
      end;
      for i:=0 to length(todos)-1 do context^.enqueue(todos[i]);
      context^.waitForFinishOfParallelTasks;
    end;
  end;

CONSTRUCTOR T_trianglesTodo.create(CONST chunkIndex_: longint; CONST target_: P_rawImage);
  VAR i:longint;
  begin
    box.x0:=0;
    box.y0:=0;
    chunkIndex :=chunkIndex_;
    with box do for i:=0 to chunkIndex-1 do begin
      x0+=CHUNK_BLOCK_SIZE;
      if x0>=target_^.dimensions.width then begin
        x0:=0;
        y0+=CHUNK_BLOCK_SIZE;
      end;
    end;
    box.x1:=box.x0+CHUNK_BLOCK_SIZE+1;
    box.y1:=box.y0+CHUNK_BLOCK_SIZE+1;
    box.x0-=1;
    box.y0-=1;
  end;

PROCEDURE T_trianglesTodo.addQuad(CONST quad:T_quad);
  begin
    if quadIsInBoundingBox(quad,box) then begin
      setLength(quadsInRange,length(quadsInRange)+1);
      quadsInRange[length(quadsInRange)-1]:=quad;
    end;
  end;

DESTRUCTOR T_trianglesTodo.destroy;
  begin
    setLength(quadsInRange,0);
  end;

PROCEDURE T_trianglesTodo.execute;
  VAR prevHit:array[0..CHUNK_BLOCK_SIZE-1,0..CHUNK_BLOCK_SIZE-1] of longint;
      background:T_colChunk;

  FUNCTION getColorAt(CONST i,j:longint; CONST x,y:double):T_rgbFloatColor; {$ifndef debugMode} inline; {$endif}
    VAR k:longint;
    begin
      if length(quadsInRange)=0 then begin
        prevHit[i,j]:=-1;
        exit(background.col[i,j].rest);
      end;
      k:=prevHit[i,j];
      if isInside(x,y,quadsInRange[k]) then exit(quadsInRange[k].color);
      for k:=0 to length(quadsInRange)-1 do if isInside(x,y,quadsInRange[k]) then begin
        prevHit[i,j]:=k;
        exit(quadsInRange[k].color);
      end;
      result:=background.col[i,j].rest;
    end;

  VAR chunk:T_colChunk;
      i,j,k:longint;
  begin
    background:=containedIn^.image.getChunkCopy(chunkIndex);
    chunk.create;
    chunk.initForChunk(containedIn^.image.dimensions.width,containedIn^.image.dimensions.height,chunkIndex);
    for i:=0 to CHUNK_BLOCK_SIZE-1 do for j:=0 to CHUNK_BLOCK_SIZE-1 do prevHit[i,j]:=0;
    for i:=0 to chunk.width-1 do for j:=0 to chunk.height-1 do with chunk.col[i,j] do rest:=getColorAt(i,j,chunk.getPicX(i),chunk.getPicY(j));

    if not(containedIn^.previewQuality) and not(containedIn^.cancellationRequested) and (length(quadsInRange)>0) then begin
      for i:=1 to chunk.width-1 do for j:=0 to chunk.height-1 do if prevHit[i-1,j]<>prevHit[i,j] then begin
        chunk.col[i-1,j].antialiasingMask:=chunk.col[i-1,j].antialiasingMask or 1;
        chunk.col[i  ,j].antialiasingMask:=chunk.col[  i,j].antialiasingMask or 1;
      end;
      for i:=0 to chunk.width-1 do for j:=1 to chunk.height-1 do if prevHit[i,j-1]<>prevHit[i,j] then begin
        chunk.col[i,j-1].antialiasingMask:=chunk.col[i,j-1].antialiasingMask or 1;
        chunk.col[i,j  ].antialiasingMask:=chunk.col[i,j  ].antialiasingMask or 1;
      end;
      for i:=0 to chunk.width-1 do for j:=0 to chunk.height-1 do with chunk.col[i,j] do if odd(antialiasingMask) then begin
        antialiasingMask:=8;
        for k:=1 to 16-1 do rest:=rest+getColorAt(i,j,
          chunk.getPicX(i)+darts_delta[k,0],
          chunk.getPicY(j)+darts_delta[k,1]);
      end;
    end;
    containedIn^.image.copyFromChunk(chunk);
    chunk.destroy;
    background.destroy;
  end;

FUNCTION findApproximatingTriangles(CONST context:P_abstractWorkflow; CONST count:longint; CONST style:byte; CONST scaler:T_scaler):T_quadList;
  VAR imgBB:T_boundingBox;
  VAR tri:array of T_triangleInfo;
  PROCEDURE addTriangleIfInBounds(CONST triangle:T_triangleInfo);
    begin
      if quadIsInBoundingBox(triangle.base,imgBB) then begin
        setLength(tri,length(tri)+1);
        tri[length(tri)-1]:=triangle;
      end;
    end;

  PROCEDURE initTriangles;
    CONST c=0.5;
          s=0.8660254037844388;
    FUNCTION area(CONST q:T_quad):double;
      begin
        result:=crossProduct(q.p0,q.p1,q.p2.re,q.p2.im);
      end;

    VAR p0,p1,p2:T_Complex;
    VAR toSplit:longint=0;
        i:longint;
        edgeToSplit:byte=0;
        l,l2:double;
        a0,a1,b0,b1:T_triangleInfo;
    begin
      p1:= 5*(-s+II*c);;
      p2:= 5*( s+II*c);;
      p0:=-5*II;
      setLength(tri,1);
      with tri[0] do begin
        base.p0:=scaler.mrofsnart(p0.re,p0.im);
        base.p1:=scaler.mrofsnart(p1.re,p1.im);
        base.p2:=scaler.mrofsnart(p2.re,p2.im);
        base.p3:=base.p0;
        base.isTriangle:=true;
        base.color:=BLACK;
        variance:=1;
      end;
      while (length(tri)<4) or (length(tri)<count shr 3) do begin
        {$ifdef DEBUGMODE}
        writeln(stderr,'INIT TRIANGLES: ',length(tri));
        {$endif}
        for i:=1 to length(tri)-1 do if area(tri[i].base)>area(tri[toSplit].base) then toSplit:=i;
        edgeToSplit:=0;
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

        tri[toSplit]:=tri[length(tri)-1];
        setLength(tri,length(tri)-1);
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
            addTriangleIfInBounds(a0);
            addTriangleIfInBounds(a1);
            addTriangleIfInBounds(b0);
            addTriangleIfInBounds(b1);
          end;
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
            addTriangleIfInBounds(a0);
            addTriangleIfInBounds(a1);
          end;
        end;
      end;
      for i:=0 to length(tri)-1 do scanTriangle(tri[i],imgBB,context^.image);
    end;

  PROCEDURE splitTriangles;
    VAR toSplit:longint=0;
        i:longint;
        edgeToSplit:byte=0;
        l,l2:double;
        a0,a1,b0,b1,c0,c1:T_triangleInfo;
    begin
      {$ifdef DEBUGMODE}
      writeln(stderr,'ADD TRIANGLES: ',length(tri));
      {$endif}

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

      tri[toSplit]:=tri[length(tri)-1];
      setLength(tri,length(tri)-1);
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
          if scanTriangle(a0,imgBB,context^.image)>0 then addTriangleIfInBounds(a0);
          if scanTriangle(a1,imgBB,context^.image)>0 then addTriangleIfInBounds(a1);
          if scanTriangle(b0,imgBB,context^.image)>0 then addTriangleIfInBounds(b0);
          if scanTriangle(b1,imgBB,context^.image)>0 then addTriangleIfInBounds(b1);
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
          addTriangleIfInBounds(a0);
          addTriangleIfInBounds(a1);
        end;
        3: begin
          a0.base.p1:=a0.base.p0*0.5+a0.base.p1*0.5; a1.base.p0:=a0.base.p1;                         //a0.p0,a1.p1
          b0.base.p2:=b0.base.p1*0.5+b0.base.p2*0.5; b1.base.p1:=b0.base.p2; b0.base.p3:=b0.base.p2; //b0.p1,b1.p2
          c0.base.p2:=c0.base.p2*0.5+c0.base.p0*0.5; c1.base.p0:=c0.base.p2; c0.base.p3:=c0.base.p2; //c0.p0,c1.p2
          scanTriangle(a0,imgBB,context^.image); scanTriangle(a1,imgBB,context^.image);
          scanTriangle(b0,imgBB,context^.image); scanTriangle(b1,imgBB,context^.image);
          scanTriangle(c0,imgBB,context^.image); scanTriangle(c1,imgBB,context^.image);
          l :=abs(a0.base.p0-a1.base.p1);
          l2:=abs(b0.base.p1-b1.base.p2);
          if l*(b0.variance+b1.variance)<l2*(a0.variance+a1.variance) then begin a0:=b0; a1:=b1; l:=l2; end;
          l2:=abs(c0.base.p0-c1.base.p2);
          if l*(c0.variance+c1.variance)<l2*(a0.variance+a1.variance) then begin a0:=c0; a1:=c1; end;
          addTriangleIfInBounds(a0);
          addTriangleIfInBounds(a1);
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
          if scanTriangle(a0,imgBB,context^.image)>0 then addTriangleIfInBounds(a0);
          if scanTriangle(a1,imgBB,context^.image)>0 then addTriangleIfInBounds(a1);
        end;
      end;
    end;

  VAR i:longint;
  begin
    imgBB.x0:=0;
    imgBB.y0:=0;
    imgBB.x1:=context^.image.dimensions.width-1;
    imgBB.y1:=context^.image.dimensions.height-1;
    initialize(tri);
    initTriangles;
    while (length(tri)<count) and not(context^.cancellationRequested) do splitTriangles;
    initialize(result);
    setLength(result,length(tri));
    for i:=0 to length(result)-1 do result[i]:=tri[i].base;
    setLength(tri,0);
  end;

PROCEDURE triangleSplit(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  VAR rawTriangles:T_quadList;
      builder:T_tileBuilder;
      scaler:T_scaler;
      i:longint;
  begin
    scaler.create(context^.image.dimensions.width,
                  context^.image.dimensions.height,
                  0,0,0.25,0);

    rawTriangles:=findApproximatingTriangles(context,parameters.i0,parameters.i1,scaler);
    builder.create(context,parameters.f2,parameters.f3);
    for i:=0 to length(rawTriangles)-1 do builder.addTriangle(rawTriangles[i]);
    setLength(rawTriangles,0);
    builder.execute(false,BLACK);
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
      circles:T_circles=();
      i,j:longint;
      tmp:T_circle;
      todo:P_spheresTodo;
      scaler:T_scaler;
  begin
    scaler.create(context^.image.dimensions.width,
                  context^.image.dimensions.height,
                  0,0,0.25,0);
    rawTriangles:=findApproximatingTriangles(context,parameters.i0,2,scaler);
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
    .addEnumChildDescription(spa_i1,'split','half-split','quarter-split','half adaptive','half adaptive 2')^
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

