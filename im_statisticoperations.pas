UNIT im_statisticOperations;
INTERFACE

USES pixMaps;

IMPLEMENTATION
USES imageManipulation,imageContexts,myParams,mypics,myColors,math,myGenerics,im_colors;
FUNCTION measure(CONST a,b:single):single;
  CONST a0=1/0.998;
        b0= -0.001;
  begin result:=sqr(a0-a)/3+(a0-a+b0-b)*(b0-b); end;

FUNCTION measure(CONST a,b:T_rgbFloatColor):single;
  begin
    result:=(measure(a[cc_red  ],b[cc_red  ])*SUBJECTIVE_GREY_RED_WEIGHT+
             measure(a[cc_green],b[cc_green])*SUBJECTIVE_GREY_GREEN_WEIGHT+
             measure(a[cc_blue ],b[cc_blue ])*SUBJECTIVE_GREY_BLUE_WEIGHT);
  end;

PROCEDURE normalizeFull_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  VAR k:longint=0;
      i:longint;
      compoundHistogram:T_compoundHistogram;
      p0,p1:T_rgbFloatColor;
      raw:P_floatColor;
  begin
    i:=parameters.i0; //pro forma; to use parameters
    raw:=context^.image.rawData;
    while k<4 do begin
      compoundHistogram:=context^.image.histogram;
      compoundHistogram.R.getNormalizationParams(p0[cc_red  ],p1[cc_red  ]);
      compoundHistogram.G.getNormalizationParams(p0[cc_green],p1[cc_green]);
      compoundHistogram.B.getNormalizationParams(p0[cc_blue ],p1[cc_blue ]);
      for i:=0 to context^.image.pixelCount-1 do raw[i]:=(raw[i]-p0)*p1;
      if (compoundHistogram.mightHaveOutOfBoundsValues or (measure(p0,p1)>1)) and not(context^.cancellationRequested) then inc(k) else k:=4;
      compoundHistogram.destroy;
    end;
  end;

PROCEDURE normalizeValue_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  VAR k:longint=0;
      compoundHistogram:T_compoundHistogram;
      raw:P_floatColor;
      i:longint;
      offset,stretch:single;
  FUNCTION normValue(CONST c:T_hsvColor):T_hsvColor; inline;
    begin
      result:=c;
      result[hc_value]:=(result[hc_value]-offset)*stretch;
    end;

  begin
    i:=parameters.i0; //pro forma; to use parameters
    raw:=context^.image.rawData;
    while k<4 do begin
      compoundHistogram:=context^.image.histogramHSV;
      compoundHistogram.B.getNormalizationParams(offset,stretch);
      for i:=0 to context^.image.pixelCount-1 do raw[i]:=normValue(raw[i]);
      if (compoundHistogram.B.mightHaveOutOfBoundsValues or (measure(offset,stretch)>1)) and not(context^.cancellationRequested) then inc(k) else k:=4;
      compoundHistogram.destroy;
    end;
  end;

PROCEDURE normalizeGrey_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  VAR k:longint=0;
      i:longint;
      compoundHistogram:T_compoundHistogram;
      greyHist:T_histogram;
      raw:P_floatColor;
      offset:T_rgbFloatColor;
      stretch:single;
  begin
    i:=parameters.i0; //pro forma; to use parameters
    raw:=context^.image.rawData;
    while k<4 do begin
      compoundHistogram:=context^.image.histogram;
      greyHist:=compoundHistogram.subjectiveGreyHistogram;
      greyHist.getNormalizationParams(offset[cc_red],stretch);
      offset:=WHITE*offset[cc_red];
      for i:=0 to context^.image.pixelCount-1 do raw[i]:=(raw[i]-offset)*stretch;
      if (greyHist.mightHaveOutOfBoundsValues or (measure(offset[cc_red],stretch)>1)) and not(context^.cancellationRequested) then inc(k) else k:=4;
      greyHist.destroy;
      compoundHistogram.destroy;
    end;
  end;

PROCEDURE compress_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  VAR i:longint;
      compoundHistogram:T_compoundHistogram;
      greyHist:T_histogram;
      raw:P_floatColor;
  begin
    raw:=context^.image.rawData;
    compoundHistogram:=context^.image.histogram;
    greyHist:=compoundHistogram.sumHistorgram;
    greyHist.smoothen(parameters.f0);
    for i:=0 to context^.image.pixelCount-1 do raw[i]:=greyHist.lookup(raw[i]);
    greyHist.destroy;
    compoundHistogram.destroy;
  end;

PROCEDURE compressV_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  VAR i:longint;
      compoundHistogram:T_compoundHistogram;
      greyHist:T_histogram;
      raw:P_floatColor;
      tempHsv:T_hsvColor;
  begin
    raw:=context^.image.rawData;
    compoundHistogram:=context^.image.histogramHSV;
    greyHist:=compoundHistogram.B;
    greyHist.smoothen(parameters.f0);
    for i:=0 to context^.image.pixelCount-1 do begin
      tempHsv:=raw[i];
      tempHsv[hc_value]:=greyHist.lookup(tempHsv[hc_value]);
      raw[i]:=tempHsv;
    end;
    compoundHistogram.destroy;
  end;

PROCEDURE compressSat_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  VAR i:longint;
      compoundHistogram:T_compoundHistogram;
      greyHist:T_histogram;
      raw:P_floatColor;
      tempHsv:T_hsvColor;
  begin
    raw:=context^.image.rawData;
    compoundHistogram:=context^.image.histogramHSV;
    greyHist:=compoundHistogram.G;
    greyHist.smoothen(parameters.f0);
    for i:=0 to context^.image.pixelCount-1 do begin
      tempHsv:=raw[i];
      tempHsv[hc_saturation]:=greyHist.lookup(tempHsv[hc_saturation]);
      raw[i]:=tempHsv;
    end;
    compoundHistogram.destroy;
  end;

PROCEDURE mono_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  VAR i:longint;
      l:T_colorChannel;
      k:longint=0;
      cSum:T_rgbFloatColor=(0,0,0);
      c:T_rgbFloatColor;
      g,invG:double;
      raw:P_floatColor;
  begin
    raw:=context^.image.rawData;
    for i:=0 to context^.image.pixelCount-1 do begin
      c:=raw[i];
      g:=greyLevel(c);
      if g>1E-3 then begin
        invG:=1/g;
        for l in RGB_CHANNELS do cSum[l]:=cSum[l]+c[l]*invG;
        inc(k);
      end;
      c[cc_red]:=g;
      raw[i]:=c;
    end;
    invG:=1/k;
    for l in RGB_CHANNELS do cSum[l]:=cSum[l]*invG;
    for i:=0 to context^.image.pixelCount-1 do begin
      c:=raw[i];
      g:=round(c[cc_red]*parameters.i0)/parameters.i0;
      for l in RGB_CHANNELS do c[l]:=g*cSum[l];
      raw[i]:=c;
    end;
  end;

PROCEDURE quantize_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  VAR i:longint;
      tree:T_colorTree;
      raw:P_floatColor;
  begin
    raw:=context^.image.rawData;
    tree.create;
    for i:=0 to context^.image.pixelCount-1 do tree.addSample(raw[i]);
    tree.finishSampling(parameters.i0);
    for i:=0 to context^.image.pixelCount-1 do raw[i]:=tree.getQuantizedColor(raw[i]);
    tree.destroy;
  end;

PROCEDURE quantizeCustom_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  CONST DEFAULT_COLOR_TABLE:array[0..255] of T_rgbColor=(
  (0,0,0),(255,255,255),(0,255,0),(255,0,0),(0,0,255),(255,255,0),(0,255,255),(255,0,255),
  (128,128,128),(255,128,0),(255,223,128),(0,0,128),(0,128,223),(255,128,255),(0,128,32),(191,0,159),
  (64,255,96),(0,96,128),(128,0,64),(159,191,191),(255,64,191),(32,191,64),(255,64,64),(255,159,64),
  (0,223,159),(32,32,191),(96,32,0),(96,32,255),(223,255,191),(128,255,32),(128,128,255),(255,128,128),
  (128,255,255),(128,128,0),(0,0,64),(255,255,64),(223,0,96),(32,191,223),(128,64,64),(255,191,0),
  (0,159,159),(64,255,159),(255,191,223),(255,32,128),(128,191,32),(159,64,223),(96,128,191),(128,64,128),
  (128,191,255),(255,64,255),(255,64,0),(0,64,64),(0,191,0),(128,191,128),(128,0,128),(255,0,191),
  (191,223,96),(96,64,191),(64,128,96),(0,255,64),(128,255,191),(255,96,96),(255,159,159),(159,64,0),
  (159,128,64),(0,96,0),(64,96,255),(96,0,223),(191,96,159),(191,128,191),(0,159,255),(64,0,32),
  (64,255,223),(32,64,223),(191,64,96),(191,0,223),(64,0,96),(0,255,191),(191,0,32),(0,0,191),
  (255,96,32),(128,159,159),(0,191,128),(0,159,64),(255,223,32),(255,32,32),(255,96,223),(128,223,0),
  (0,255,128),(223,159,223),(159,96,32),(64,64,159),(159,223,64),(0,223,32),(0,191,191),(0,32,159),
  (223,191,128),(159,64,159),(64,191,96),(96,64,32),(96,191,0),(128,255,128),(64,64,96),(191,159,96),
  (191,255,159),(32,96,64),(128,159,223),(0,96,191),(223,223,255),(96,159,32),(159,223,159),(255,32,223),
  (223,159,32),(159,223,223),(128,0,191),(0,32,223),(32,128,128),(32,255,32),(255,0,64),(0,64,255),
  (223,96,128),(223,255,96),(64,159,159),(191,96,223),(32,32,128),(191,64,191),(96,191,191),(223,128,159),
  (223,128,64),(255,128,191),(191,128,255),(223,191,191),(32,64,32),(96,191,64),(191,255,223),(191,255,0),
  (159,32,255),(96,128,64),(32,128,0),(32,159,32),(191,191,255),(255,255,159),(159,0,96),(32,32,0),
  (223,223,64),(191,64,255),(64,128,223),(96,0,159),(0,128,96),(64,0,255),(32,128,191),(191,128,0),
  (64,191,255),(0,64,96),(0,255,223),(96,64,223),(64,191,128),(0,255,96),(255,32,159),(255,159,96),
  (0,191,96),(128,64,96),(255,255,223),(64,255,255),(191,0,64),(64,0,64),(128,0,32),(191,64,64),
  (64,255,64),(159,128,96),(191,0,191),(0,0,96),(64,255,191),(223,0,128),(191,0,0),(0,0,32),
  (64,255,128),(255,0,159),(0,96,255),(0,223,0),(128,223,32),(159,191,64),(191,32,32),(0,64,159),
  (255,64,32),(0,0,223),(0,0,159),(223,191,32),(255,64,96),(0,128,159),(255,0,223),(0,255,159),
  (128,191,159),(255,255,128),(128,32,128),(255,191,159),(128,255,0),(128,96,128),(0,191,255),(255,159,0),
  (96,96,32),(223,223,191),(96,159,191),(128,191,223),(255,32,0),(96,64,0),(255,255,32),(0,223,191),
  (64,128,159),(128,96,96),(96,96,191),(191,255,32),(191,159,255),(64,191,159),(191,191,0),(128,96,255),
  (64,159,255),(128,191,96),(96,32,223),(128,32,159),(255,0,32),(96,128,32),(128,223,128),(191,223,0),
  (255,223,223),(159,128,32),(255,32,96),(64,64,128),(64,96,159),(64,96,96),(255,223,159),(128,159,128),
  (0,128,255),(255,64,159),(255,223,0),(255,32,191),(128,128,223),(64,159,96),(255,64,223),(64,32,64),
  (128,32,64),(191,128,223),(159,159,64),(191,191,96),(191,255,128),(255,32,64),(128,159,255),(255,128,96),
  (128,255,96),(191,96,255),(0,96,159),(0,32,32),(0,96,96),(0,32,255),(159,255,64),(191,32,191));
  CONST ALTERNATIVE_COLOR_TABLE:array[0..255] of T_rgbColor=(
  (  0,  0,  0),(255,255,255),(  0,112,255),(255,  0,167),( 50,255,  0),(227,139,  6),( 76,245,186),(188,131,194),( 74,  0,162),( 15,129, 85),(203,255, 82),(180,  4,  0),(102, 87,  0),(163, 57,109),(157, 38,255),(123,181, 52),
  ( 98,170,252),(  0, 15,255),(  0,223, 97),(255,193,150),(  8, 41, 90),(  0,168,177),(255, 64, 59),( 79, 93,174),(181,209,218),(255, 72,245),(100,166,145),(255,164,255),(149,243,  0),( 40,156,  0),( 99,  0, 64),(  0,219,255),
  (  0, 81, 14),(102,254, 91),(216,121,103),(255,219,  0),(133,116, 77),(229,  0, 75),(167,  1,172),(127,104,255),(177,195,120),( 88,  0,243),(196, 65,187),( 60, 62,241),(  0, 46,177),(127,255,255),(230,  9,255),(186, 73, 10),
  ( 67, 81, 68),(241,175, 71),(231,255,166),(153,255,157),( 53,205, 41),(151,138,  0),( 59, 39, 18),(  0,108,152),(190,193, 15),(255, 79,143),( 22,165,240),( 90, 50,125),( 47,179, 99),(  0,228,167),(  1,  0,137),( 77,141, 52),
  (255,136,174),(145,103,148),(121, 44,191),(125,207,180),( 66,123,226),(136,159,201),(197, 99,255),(163,  0, 98),( 74,220,255),(241, 27,  1),( 36,255,231),(  0,216,  0),(113,205,107),(140, 42, 45),(214,175,190),(211, 28,134),
  ( 60,126,131),(154,225, 63),( 46,  1, 96),(  3,252, 47),( 18,  0,199),(234,210,248),( 57,229,130),(  0,170, 48),(246,247, 48),(255,234,113),(192,255,251),(197, 39, 60),(203,104, 48),( 19, 89,205),(178,158,255),(170,151, 96),
  ( 33, 78,119),( 29,118, 33),(213, 22,197),( 61,247, 55),(103,207,  0),(  0,132,209),( 66,185,198),(150, 77,215),(252, 93,  0),(197,221,163),(114,  8,  0),(219,102,169),(244,119,234),(208, 53,243),(127,212,237),(102,132,177),
  ( 99, 93,113),(247, 53,190),( 17, 16, 47),(205, 80,122),( 42, 32,143),(  2,191,133),(114, 13,112),( 94,132,  0),(214,213, 65),( 71, 36,183),(  0, 84, 69),(145, 87, 39),(248,234,209),(151,147,149),(125,247,204),( 10,255,128),
  (193,155, 44),(145,  0,226),( 51,156,162),( 78, 39, 75),(116,101,202),(114, 64,253),(157,235,112),(105,150, 95),(152, 66,165),(255,148,114),(255, 42,111),( 54, 19,221),(117,250, 41),(  0,147,130),(122,  8,159),(117, 69, 76),
  ( 58,  0,  3),(  0,255,198),(242, 92, 91),( 40,202,163),( 82,217, 75),(206,255,  0),(142,179,245),(238,180,  0),(180,248,200),(  0,211, 53),(163,228,255),( 27,215,210),(186,  0, 52),( 81,174, 23),(100, 34,230),(207,149,145),
  (223, 56, 26),( 44, 66,167),(186, 11,243),(170, 37,207),(190, 75, 74),(161, 40,  0),(157, 26,135),( 78,115, 83),(141,  2, 40),(178,175,161),( 28, 57, 48),( 92, 72,211),(251,  5,117),(  3, 51,227),(176,255, 40),(255,208, 50),
  (149,125,220),(247, 38,235),(116,115, 34),(103,255,143),(225,202,114),(255,188,207),(245,224,163),(255,125, 53),(207,171,100),(  4, 40,  9),(132,129,117),(  0, 52,132),(255,  6,216),( 39,252, 94),(223, 87,217),(145,195, 14),
  ( 53,190,250),( 60,104,  4),(201,249,131),( 75,157,220),(218,225, 21),(219, 54, 95),(120,165,  0),(129,225,144),(217,151,230),( 50, 49,105),( 73,180, 64),(176,189, 67),(187,113,139),(178,224, 19),(129, 49,139),( 98,206, 40),
  ( 42,193,  0),(189,112,  0),(  0,255,  5),( 38,155, 67),( 87,217,213),( 57, 76, 26),(221, 18, 39),(  0,134,  3),( 47,124,184),( 89,203,148),(170,102, 97),( 71,108, 43),(  0,104,111),(223, 58,152),(101, 61, 33),( 83,235, 19),
  (111,140,235),( 37, 91,248),(  0,186,213),(  0, 76,161),(165,126, 45),( 54,156,123),(176, 97,179),(163,166, 19),(  0,187, 86),(139,176,108),(144,255, 80),(106, 75,150),(  0,176,  7),(137, 33, 86),( 44,212, 98),( 85, 91,249),
  (207,121,227),( 88,177,110),(127, 60,  0),(172, 71,255),( 76, 20, 45),(223,255,226),(195, 19, 95),( 40,179,141),(152, 99,  0),( 98, 32,156),(139,149, 65),(169,180,205),(107,  6,201),( 35,241,183),( 42,224, 11),(255, 99,192));
  TYPE T_colorTable=array of T_rgbFloatColor;
  VAR colorTable:T_colorTable;
      colorSource:P_rawImage=nil;

  PROCEDURE ensureColorSource;
    VAR scalePow,i,j: longint;
        diff: extended;
        raw: P_floatColor;
    begin
      if colorSource<>nil then exit;
      scalePow:=1;
      diff:=0.25;
      while (context^.image.dimensions.width shr scalePow)*(context^.image.dimensions.height shr scalePow)>65536 do begin
        scalePow+=1; diff*=0.25;
      end;
      new(colorSource,create(context^.image.dimensions.width  shr scalePow,
                             context^.image.dimensions.height shr scalePow));
      colorSource^.clearWithColor(BLACK);
      for j:=0 to colorSource^.dimensions.height shl scalePow-1 do begin
        raw:=context^.image.linePtr(j);
        for i:=0 to colorSource^.dimensions.width shl scalePow-1 do
          colorSource^.multIncPixel(i shr scalePow,j shr scalePow,1,raw[i]*diff);
      end;
    end;

  PROCEDURE standardAdaptiveColors;
    VAR i:longint;
        tree:T_colorTree;
        raw:P_floatColor;
    begin
      ensureColorSource;
      raw:=colorSource^.rawData;
      tree.create;
      for i:=0 to colorSource^.pixelCount-1 do tree.addSample(raw[i]);
      tree.finishSampling(parameters.i0);
      colorTable:=tree.colorTable;
      tree.destroy;
    end;

  PROCEDURE simpleLinearColors;
    VAR i:longint;
        raw:P_floatColor;
        tmp:T_rgbFloatColor;
        hsv_global,hsv:T_hsvColor;
        r:double=0;
        g:double=0;
        b:double=0;
    begin
      ensureColorSource;
      raw:=colorSource^.rawData;
      for i:=0 to colorSource^.pixelCount-1 do begin
        tmp:=raw[i];
        r+=tmp[cc_red];
        g+=tmp[cc_green];
        b+=tmp[cc_blue];
      end;
      i:=colorSource^.pixelCount;
      hsv_global:=rgbColor(r/i,g/i,b/i);
      setLength(colorTable,parameters.i0);
      for i:=0 to length(colorTable)-1 do begin
        hsv:=hsv_global;
        r:=2*i/(length(colorTable)-1);
        if r<=1 then begin
          hsv[hc_value]:=r;
          hsv[hc_saturation]:=1;
        end else begin
          r-=1;
          hsv[hc_value]:=1;
          hsv[hc_saturation]:=1-r;
        end;
        colorTable[i]:=hsv;
      end;
    end;

  TYPE T_sample=record
         color:T_rgbColor;
         count:longint;
       end;
       T_colorList=record
         sample:array of T_sample;
         spread:T_rgbFloatColor;
         maxSpread:single;
       end;
       T_colorLists=array of T_colorList;

  FUNCTION averageColor(CONST bucket:T_colorList):T_rgbFloatColor;
    VAR s:T_sample;
        count:longint=0;
    begin
      result:=BLACK;
      for s in bucket.sample do begin
        result+=s.color*s.count;
        count +=        s.count;
      end;
      result*=1/count;
    end;

  PROCEDURE updateSpreads(VAR bucket:T_colorList);
    VAR r :double=0;
        g :double=0;
        b :double=0;
        rr:double=0;
        gG:double=0;
        bb:double=0;
        count:longint=0;
        s:T_sample;
    begin
      with bucket do begin
        for s in sample do begin
          count+=                    s.count;
          r +=    s.color[cc_red  ] *s.count;
          g +=    s.color[cc_green] *s.count;
          b +=    s.color[cc_blue ] *s.count;
          rr+=sqr(s.color[cc_red  ])*s.count;
          gG+=sqr(s.color[cc_green])*s.count;
          bb+=sqr(s.color[cc_blue ])*s.count;
        end;
        spread:=rgbColor(SUBJECTIVE_GREY_RED_WEIGHT  *(rr-sqr(r)/count),
                         SUBJECTIVE_GREY_GREEN_WEIGHT*(gG-sqr(g)/count),
                         SUBJECTIVE_GREY_BLUE_WEIGHT *(bb-sqr(b)/count));
        if length(sample)<=1
        then maxSpread:=-1
        else maxSpread:=spread[cc_red]+spread[cc_green]+spread[cc_blue];
      end;
    end;

  PROCEDURE split(VAR list:T_colorList; OUT halfList:T_colorList);
    VAR channel:T_colorChannel;
    FUNCTION partition(CONST Left,Right:longint):longint;
      VAR pivot:byte;
          i:longint;
          tmp:T_sample;
      begin
        pivot:=list.sample[Left+(Right-Left) shr 1].color[channel];
        result:=Left;
        for i:=Left to Right-1 do if list.sample[i].color[channel]<pivot then begin
          tmp                :=list.sample[result];
          list.sample[result]:=list.sample[i];
          list.sample[i     ]:=tmp;
          inc(result);
        end;
      end;

    PROCEDURE sort(CONST Left,Right:longint);
      VAR pivotIdx:longint;
      begin
        if Left=Right then exit;
        pivotIdx:=partition(Left,Right);
        if pivotIdx>Left  then sort(Left,pivotIdx-1);
        if pivotIdx<Right then sort(pivotIdx+1,Right);
      end;

    VAR i,i0,splitCount:longint;
        popCount:longint=0;
    begin
      if list.spread[cc_red]>list.spread[cc_green] then channel:=cc_red else channel:=cc_green;
      if list.spread[cc_blue]>list.spread[channel] then channel:=cc_blue;
      sort(0,length(list.sample)-1);
      for i:=0 to length(list.sample)-1 do popCount+=list.sample[i].count;
      splitCount:=popCount shr 1;
      popCount:=0; i0:=0;
      while (popCount<splitCount) do begin
        popCount+=list.sample[i0].count;
        inc(i0);
      end;
      if i0=length(list.sample) then dec(i0);
      initialize(halfList);
      setLength(halfList.sample,length(list.sample)-i0);
      for i:=0 to length(halfList.sample)-1 do halfList.sample[i]:=list.sample[i+i0];
      updateSpreads(halfList);

      setLength(list.sample,i0);
      updateSpreads(list);
    end;

  FUNCTION dropEmptyBuckets(VAR buckets:T_colorLists):boolean;
    VAR i,i0:longint;
    begin
      i0:=0;
      for i:=0 to length(buckets)-1 do if length(buckets[i].sample)>0 then begin
        if i0<>i then buckets[i0]:=buckets[i];
        inc(i0);
      end;
      if i0<>length(buckets) then begin
        setLength(buckets,i0);
        result:=true;
      end else result:=false;
    end;

  FUNCTION splitOneList(VAR buckets:T_colorLists):boolean;
    VAR i:longint;
        toSplit:longint=0;
    begin
      for i:=1 to length(buckets)-1 do if buckets[i].maxSpread>buckets[toSplit].maxSpread then toSplit:=i;
      if buckets[toSplit].maxSpread<0 then exit(false) else result:=true;
      i:=length(buckets);
      setLength(buckets,i+1);
      split(buckets[toSplit],buckets[i]);
      if length(buckets[toSplit].sample)=0 then begin
        buckets[toSplit]:=buckets[i];
        buckets[toSplit].maxSpread:=-1;
        setLength(buckets,i);
      end else if length(buckets[i].sample)=0 then begin
        buckets[toSplit].maxSpread:=-1;
        setLength(buckets,i);
      end;
    end;

  FUNCTION medianCutBuckets(CONST targetBucketCount:longint):T_colorLists;
    VAR buckets:T_colorLists;
    FUNCTION splitAllLists:boolean;
      VAR i,i0:longint;
      begin
        i0:=length(buckets);
        setLength(buckets,i0+i0);
        for i:=0 to i0-1 do split(buckets[i],buckets[i0+i]);
        dropEmptyBuckets(buckets);
        result:=length(buckets)>i0;
      end;

    FUNCTION firstBucket:T_colorList;
      VAR raw:P_floatColor;
          i,j:longint;
          tmp:T_rgbColor;
          arr:T_arrayOfLongint=();
      PROCEDURE prepareColorList; inline;
        begin
          sort(arr);
          j:=0; i:=0;
          setLength(result.sample,length(arr));
          tmp[cc_red  ]:= arr[i]         and 255;
          tmp[cc_green]:=(arr[i] shr  8) and 255;
          tmp[cc_blue ]:= arr[i] shr 16;
          result.sample[0].color:=tmp; inc(i);
          result.sample[0].count:=1;
          while i<length(arr) do begin
            if arr[i]=arr[i-1] then inc(result.sample[j].count)
            else begin
              inc(j);
              tmp[cc_red  ]:= arr[i]         and 255;
              tmp[cc_green]:=(arr[i] shr  8) and 255;
              tmp[cc_blue ]:= arr[i] shr 16;
              result.sample[j].color:=tmp;
              result.sample[j].count:=1;
            end;
            inc(i);
          end;
          setLength(arr,0);
          setLength(result.sample,j+1);
        end;

      VAR channel:T_colorChannel;
      begin
        ensureColorSource;
        raw:=colorSource^.rawData;
        setLength(arr,colorSource^.pixelCount);
        for i:=0 to colorSource^.pixelCount-1 do begin
          tmp:=projectedColor(raw[i]);
          arr[i]:=(tmp[cc_red] or longint(tmp[cc_green]) shl 8 or longint(tmp[cc_blue]) shl 16);
        end;
        prepareColorList;
        if length(result.sample)>50000*27 then begin
          setLength(arr,colorSource^.pixelCount);
          for i:=0 to colorSource^.pixelCount-1 do begin
            tmp:=projectedColor(raw[i]);
            for channel in RGB_CHANNELS do
              tmp[channel]:=round(tmp[channel]/3)*3;
            arr[i]:=(tmp[cc_red] or longint(tmp[cc_green]) shl 8 or longint(tmp[cc_blue]) shl 16);
          end;
          prepareColorList;
        end else if length(result.sample)>50000*8 then begin
          setLength(arr,colorSource^.pixelCount);
          for i:=0 to colorSource^.pixelCount-1 do begin
            tmp:=projectedColor(raw[i]);
            for channel in RGB_CHANNELS do begin
              if tmp[channel]<127 then begin
                if odd(tmp[channel]) then dec(tmp[channel]);
              end else begin
                if not(odd(tmp[channel])) then inc(tmp[channel]);
              end;
            end;
            arr[i]:=(tmp[cc_red] or longint(tmp[cc_green]) shl 8 or longint(tmp[cc_blue]) shl 16);
          end;
          prepareColorList;
        end;
        {$ifdef debugMode}
        writeln(stdErr,'DEBUG: median cut works on ',length(result.sample),' distinct colors');
        {$endif}
        updateSpreads(result);
      end;

    begin
      setLength(buckets,1);
      buckets[0]:=firstBucket;
      while (length(buckets)*3<=targetBucketCount) and not context^.cancellationRequested and splitAllLists do begin end;
      while (length(buckets)  < targetBucketCount) and not context^.cancellationRequested and splitOneList(buckets) do begin end;
      result:=buckets;
    end;

  PROCEDURE medianCutColors;
    VAR k:longint;
        buckets:T_colorLists;
    begin
      buckets:=medianCutBuckets(parameters.i0);
      setLength(colorTable,length(buckets));
      for k:=0 to length(buckets)-1 do begin
        colorTable[k]:=averageColor(buckets[k]);
        setLength(buckets[k].sample,0);
      end;
      setLength(buckets,0);
    end;

  PROCEDURE modifiedMedianCut;
    VAR k:longint;
        i:longint=0;
        buckets:T_colorLists;
        allSamples:array of T_sample=();
        sample:T_sample;
    PROCEDURE collectAveragePerBucket;
      VAR k:longint;
      begin
        //collect average colors per bucket
        setLength(colorTable,length(buckets));
        for k:=0 to length(buckets)-1 do begin
          colorTable[k]:=averageColor(buckets[k]);
          i+=length(buckets[k].sample);
        end;
      end;

    PROCEDURE redistributeSamples;
      VAR sample:T_sample;
          k,i:longint;
          dist,bestDist:double;
      begin
        //redistribute samples
        for sample in allSamples do begin
          bestDist:=infinity; i:=0;
          for k:=0 to length(colorTable)-1 do begin
            dist:=colDiff(colorTable[k],sample.color);
            if dist<bestDist then begin
              bestDist:=dist;
              i:=k;
            end;
          end;
          setLength(buckets[i].sample,length(buckets[i].sample)+1);
                    buckets[i].sample[length(buckets[i].sample)-1]:=sample;
        end;
      end;

    begin
      buckets:=medianCutBuckets(parameters.i0);
      collectAveragePerBucket;
      //collect all samples
      setLength(allSamples,i);
      i:=0;
      for k:=0 to length(buckets)-1 do begin
        for sample in buckets[k].sample do begin
          allSamples[i]:=sample;
          inc(i);
        end;
        setLength(buckets[k].sample,0);
      end;
      redistributeSamples;
      //while some buckets remain empty, drop them and resplit
      while dropEmptyBuckets(buckets) and not context^.cancellationRequested do begin
        for k:=0 to length(buckets)-1 do updateSpreads(buckets[k]);
        while (length(buckets) < parameters.i0) and not context^.cancellationRequested and splitOneList(buckets) do begin end;
        collectAveragePerBucket;
        for k:=0 to length(buckets)-1 do setLength(buckets[k].sample,0);
        redistributeSamples;
      end;

      collectAveragePerBucket;
      for k:=0 to length(buckets)-1 do setLength(buckets[k].sample,0);
      setLength(buckets,0);
    end;

  PROCEDURE kMeansColorTable;
    VAR allSamples:array of T_sample=();
        buckets:T_colorLists;
        nextDefaultColor:longint;
    FUNCTION redistributeSamples:boolean;
      VAR i:longint;
          popCount:longint;
          s:T_sample;
          tmp,
          bestDist:double;
          bestIdx :longint;
          previousBucketSizes:T_arrayOfLongint=();
      begin
        setLength(previousBucketSizes,length(buckets));
        for i:=0 to length(buckets)-1 do begin
          previousBucketSizes[i]:=length(buckets[i].sample);
          setLength(buckets[i].sample,0);
        end;
        //Cost = O(length(allSamples.sample) * length(buckets)
        for s in allSamples do begin
          bestDist:=infinity;
          bestIdx :=-1;
          for i:=0 to length(buckets)-1 do begin
            tmp:=colDiff(buckets[i].spread,s.color);
            if tmp<bestDist then begin
              bestIdx :=i;
              bestDist:=tmp;
            end;
          end;
          with buckets[bestIdx] do begin
            i:=length(sample);
            setLength(sample,i+1);
            sample[i]:=s;
          end;
        end;
        result:=false;
        for i:=0 to length(buckets)-1 do with buckets[i] do begin
          if length(sample)<>previousBucketSizes[i] then result:=true;
          popCount:=0;
          spread:=BLACK;
          for s in sample do begin
            spread+=s.color*s.count;
            popCount+=      s.count;
          end;
          if popCount=0
          then begin
            if nextDefaultColor<length(DEFAULT_COLOR_TABLE)
            then begin
              spread:=DEFAULT_COLOR_TABLE[nextDefaultColor];
              inc(nextDefaultColor);
              result:=true;
            end else spread:=BLACK;
          end else spread*=(1/popCount);
        end;
      end;

    VAR i,j,k:longint;
    begin
      buckets:=medianCutBuckets(parameters.i0);
      k:=0;
      for i:=0 to length(buckets)-1 do k+=length(buckets[i].sample);
      setLength(allSamples,k);
      k:=0;
      for i:=0 to length(buckets)-1 do for j:=0 to length(buckets[i].sample)-1 do begin
        allSamples[k]:=buckets[i].sample[j];
        inc(k);
      end;
      for i:=0 to length(buckets)-1 do buckets[i].spread:=averageColor(buckets[i]);
      nextDefaultColor:=0;
      i:=0;
      while (i*length(buckets)*length(allSamples)<20000000) and redistributeSamples and not(context^.cancellationRequested) do i+=1;
      setLength(colorTable,length(buckets));
      for i:=0 to length(colorTable)-1 do colorTable[i]:=buckets[i].spread;
    end;

  PROCEDURE defaultColorTable;
    VAR k:longint;
    begin
      setLength(colorTable,parameters.i0);
      for k:=0 to length(colorTable)-1 do colorTable[k]:=DEFAULT_COLOR_TABLE[k];
    end;

  PROCEDURE boundsColorTable;
    VAR k:longint;
    begin
      setLength(colorTable,parameters.i0);
      for k:=0 to length(colorTable)-1 do colorTable[k]:=ALTERNATIVE_COLOR_TABLE[k];
    end;

  PROCEDURE bruteForceColorTable;
    VAR i,j:longint;
        raw:P_floatColor;
        avgColor:T_rgbColor=(0,0,0);
        diff,
        minDiff,
        greatestDiff:double;
        nextColor:T_rgbColor;

        colorTableIndex:longint;
    begin
      ensureColorSource;
      raw:=colorSource^.rawData;
      for i:=0 to colorSource^.pixelCount-1 do avgColor+=raw[i];
      avgColor*=(1/colorSource^.pixelCount);
      greatestDiff:=0;
      for i:=0 to colorSource^.pixelCount-1 do begin
        diff:=colDiff(avgColor,raw[i]);
        if diff>greatestDiff then begin
          greatestDiff:=diff;
          nextColor:=raw[i];
        end;
      end;

      setLength(colorTable,parameters.i0);
      colorTable[0]:=nextColor;

      for colorTableIndex:=1 to parameters.i0-1 do begin
        greatestDiff:=0;
        for i:=0 to colorSource^.pixelCount-1 do begin
          minDiff:=1E20;
          for j:=0 to colorTableIndex-1 do begin
            diff:=colDiff(raw[i],colorTable[j]);
            if diff<minDiff then minDiff:=diff;
          end;
          if minDiff>greatestDiff then begin
            greatestDiff:=minDiff;
            nextColor:=raw[i];
          end;
        end;
        colorTable[colorTableIndex]:=nextColor;
      end;
    end;

  PROCEDURE bruteForceMedianCut;
    VAR buckets:T_colorLists;
        chunks:array of record
          pending:boolean;
          color:T_rgbFloatColor;
        end;
        colorTableIndex,i,j,k: longint;
        greatestDiff,
        minDiff,
        diff: double;
        avgColor :T_rgbFloatColor=(0,0,0);
        nextColor:T_rgbFloatColor;

    begin
      ensureColorSource;
      buckets:=medianCutBuckets(parameters.i0*64);
      setLength(chunks,length(buckets));
      i:=0;
      for k:=0 to length(chunks)-1 do begin
        chunks[k].color  :=averageColor(buckets[k]);
        chunks[k].pending:=true;
        avgColor+=chunks[k].color*length(buckets[k].sample);
        i+=                       length(buckets[k].sample);
      end;
      avgColor*=1/i;

      setLength(buckets,0);
      setLength(colorTable,parameters.i0);
      greatestDiff:=0;
      for i:=0 to length(chunks)-1 do begin
        diff:=colDiff(avgColor,chunks[i].color);
        if diff>greatestDiff then begin
          greatestDiff:=diff;
          nextColor:=chunks[i].color;
          k:=i;
        end;
      end;

      colorTable[0]:=nextColor;
      chunks[k].pending:=false;
      for colorTableIndex:=1 to parameters.i0-1 do begin
        greatestDiff:=0;
        for i:=0 to length(chunks)-1 do if chunks[i].pending then begin
          minDiff:=infinity;
          for j:=0 to colorTableIndex-1 do begin
            diff:=colDiff(chunks[i].color,colorTable[j]);
            if diff<minDiff then minDiff:=diff;
          end;
          if minDiff>greatestDiff then begin
            greatestDiff:=minDiff;
            nextColor:=chunks[i].color;
            k:=i;
          end;
        end;
        colorTable[colorTableIndex]:=nextColor;
        chunks[k].pending:=false;
      end;
      setLength(chunks,0);
    end;

  FUNCTION nearestColor(CONST pixel:T_rgbFloatColor):T_rgbFloatColor;
    VAR k      :longint;
        kBest  :longint=-1;
        dist   :double;
        minDist:double=infinity;
    begin
      for k:=0 to length(colorTable)-1 do begin
        dist:=colDiff(colorTable[k],pixel);
        if dist<minDist then begin
          minDist:=dist;
          kBest  :=k;
        end;
      end;
      if kBest<0 then result:=colorTable[0]
                 else result:=colorTable[kBest];
    end;

  PROCEDURE noDither;
    VAR k:longint;
        p:P_floatColor;
    begin
      p:=context^.image.rawData;
      for k:=0 to context^.image.pixelCount-1 do p[k]:=nearestColor(p[k]);
    end;

  PROCEDURE floydSteinbergDither;
    VAR x,y,xm,ym:longint;
        oldPixel,newPixel,error:T_rgbFloatColor;
    begin
      xm:=context^.image.dimensions.width -1;
      ym:=context^.image.dimensions.height-1;
      for y:=0 to ym do if not(context^.cancellationRequested) then for x:=0 to xm do begin
        oldPixel:=context^.image[x,y]; newPixel:=nearestColor(oldPixel); context^.image[x,y]:=newPixel; error:=(oldPixel-newPixel)*0.05625;
        if x<xm then context^.image.multIncPixel(x+1,y,1,error*7);
        if y<ym then begin
          if x>0  then context^.image.multIncPixel(x-1,y+1,1,error*3);
                       context^.image.multIncPixel(x  ,y+1,1,error*5);
          if x<xm then context^.image.multIncPixel(x+1,y+1,1,error*1);
        end;
      end;
    end;

  PROCEDURE atkinsonDither;
    VAR x,y,xm,ym:longint;
        oldPixel,newPixel,error:T_rgbFloatColor;
    begin
      xm:=context^.image.dimensions.width -1;
      ym:=context^.image.dimensions.height-1;
      for y:=0 to ym do if not(context^.cancellationRequested) then for x:=0 to xm do begin
        oldPixel:=context^.image[x,y]; newPixel:=nearestColor(oldPixel);
        context^.image[x,y]:=newPixel;
        error:=(oldPixel-newPixel)*0.125;
        if x<xm   then context^.image.multIncPixel(x+1,y,1,error);
        if x<xm-1 then context^.image.multIncPixel(x+2,y,1,error);
        if y<ym then begin
          if x>0  then context^.image.multIncPixel(x-1,y+1,1,error);
                       context^.image.multIncPixel(x  ,y+1,1,error);
          if x<xm then context^.image.multIncPixel(x+1,y+1,1,error);
        end;
        if y<ym-1 then context^.image.multIncPixel(x  ,y+2,1,error);
      end;
    end;

  PROCEDURE jarvisJudiceNinkeDither;
    VAR x,y,xm,ym:longint;
        oldPixel,newPixel,error:T_rgbFloatColor;
    begin
      xm:=context^.image.dimensions.width -1;
      ym:=context^.image.dimensions.height-1;
      for y:=0 to ym do if not(context^.cancellationRequested) then for x:=0 to xm do begin
        oldPixel:=context^.image[x,y]; newPixel:=nearestColor(oldPixel); context^.image[x,y]:=newPixel; error:=oldPixel-newPixel;
        if x<xm   then context^.image.multIncPixel(x+1,y,1,error*0.1458);
        if x<xm-1 then context^.image.multIncPixel(x+2,y,1,error*0.1041);
        if y<ym then begin
          if x>1    then context^.image.multIncPixel(x-2,y+1,1,error*0.0625);
          if x>0    then context^.image.multIncPixel(x-1,y+1,1,error*0.1041);
                         context^.image.multIncPixel(x  ,y+1,1,error*0.1458);
          if x<xm   then context^.image.multIncPixel(x+1,y+1,1,error*0.1041);
          if x<xm-1 then context^.image.multIncPixel(x+2,y+1,1,error*0.0625);
        end;
        if y<ym-1 then begin
          if x>1    then context^.image.multIncPixel(x-2,y+2,1,error*0.0208);
          if x>0    then context^.image.multIncPixel(x-1,y+2,1,error*0.0625);
                         context^.image.multIncPixel(x  ,y+2,1,error*0.1041);
          if x<xm   then context^.image.multIncPixel(x+1,y+2,1,error*0.0625);
          if x<xm-1 then context^.image.multIncPixel(x+2,y+2,1,error*0.0208);
        end;
      end;
    end;

  PROCEDURE lineBasedDither;
    VAR x,y,xm,ym:longint;
        oldPixel,newPixel,error:T_rgbFloatColor;
    begin
      xm:=context^.image.dimensions.width -1;
      ym:=context^.image.dimensions.height-1;
      error:=BLACK;
      for y:=0 to ym do
      if odd(y)
      then for x:=0 to xm     do begin oldPixel:=context^.image[x,y]+error; newPixel:=nearestColor(oldPixel); error:=(oldPixel-newPixel)*0.98; context^.image[x,y]:=newPixel; end
      else for x:=xm downto 0 do begin oldPixel:=context^.image[x,y]+error; newPixel:=nearestColor(oldPixel); error:=(oldPixel-newPixel)*0.98; context^.image[x,y]:=newPixel; end;
    end;

  PROCEDURE kochCurveDither;
    VAR n:longint;
    PROCEDURE d2xy(CONST d:longint; OUT x,y:longint);
      PROCEDURE rot(CONST n:longint; VAR x,y:longint; CONST rx,ry:longint);
        VAR tmp:longint;
        begin
          if (ry=0) then begin
            if (rx=1) then begin
              x:=n-1-x;
              y:=n-1-y;
            end;
            tmp:=x; x:=y; y:=tmp;
          end;
        end;
      VAR rx,ry,t:longint;
          s:longint=1;
      begin
        t:=d;
        x:=0;
        y:=0;
        while s<n do begin
          rx:=1 and (t shr 1);
          ry:=1 and (t xor rx);
          rot(s,x,y,rx,ry);
          x+=s*rx;
          y+=s*ry;
          t:=t shr 2;
          s*=2;
        end;
      end;

    VAR k,xm,ym,x,y:longint;
        error,oldPixel,newPixel:T_rgbFloatColor;
    begin
      xm:=context^.image.dimensions.width -1;
      ym:=context^.image.dimensions.height-1;
      n:=1;
      while (n<=xm) or (n<=ym) do n*=2;
      error:=BLACK;
      for k:=0 to sqr(n)-1 do begin
        d2xy(k,x,y);
        if (x>=0) and (x<=xm) and (y>=0) and (y<=ym) and not(context^.cancellationRequested) then begin
          oldPixel:=context^.image[x,y]+error;
          newPixel:=nearestColor(oldPixel);
          context^.image[x,y]:=newPixel;
          error:=(oldPixel-newPixel)*0.9;
        end else error:=BLACK;
      end;
    end;

  PROCEDURE blockDither_4x4;
    CONST KOCH:array[0..15,0..15] of longint=((0,1,2,3,7,6,10,11,15,14,13,12,8,9,5,4),
                                              (1,2,3,7,6,10,11,15,14,13,12,8,9,5,4,0),
                                              (2,3,7,6,10,11,15,14,13,12,8,9,5,4,0,1),
                                              (3,7,6,10,11,15,14,13,12,8,9,5,4,0,1,2),
                                              (4,0,1,2,3,7,6,10,11,15,14,13,12,8,9,5),
                                              (5,4,0,1,2,3,7,6,10,11,15,14,13,12,8,9),
                                              (6,10,11,15,14,13,12,8,9,5,4,0,1,2,3,7),
                                              (7,6,10,11,15,14,13,12,8,9,5,4,0,1,2,3),
                                              (8,9,5,4,0,1,2,3,7,6,10,11,15,14,13,12),
                                              (9,5,4,0,1,2,3,7,6,10,11,15,14,13,12,8),
                                              (10,11,15,14,13,12,8,9,5,4,0,1,2,3,7,6),
                                              (11,15,14,13,12,8,9,5,4,0,1,2,3,7,6,10),
                                              (12,8,9,5,4,0,1,2,3,7,6,10,11,15,14,13),
                                              (13,12,8,9,5,4,0,1,2,3,7,6,10,11,15,14),
                                              (14,13,12,8,9,5,4,0,1,2,3,7,6,10,11,15),
                                              (15,14,13,12,8,9,5,4,0,1,2,3,7,6,10,11));

    VAR xm,ym,ix,iy,dx,dy,k:longint;
        col:array[0..15] of T_rgbFloatColor;
        err:T_rgbFloatColor;
        e_,e_max:double;
        k_start:longint;

        oldPixel:T_rgbFloatColor;
    begin
      xm:=context^.image.dimensions.width -1;
      ym:=context^.image.dimensions.height-1;
      for iy:=0 to ym do if (iy and 3=0) then
      for ix:=0 to xm do if (ix and 3=0) then begin
        //Fetch block:
        for dy:=0 to 3 do if iy+dy<=ym then begin
          for dx:=0 to 3 do if ix+dx<=xm
          then col[dx+4*dy]:=context^.image[ix+dx,iy+dy]
          else col[dx+4*dy]:=col[dx+4*dy-1];
        end else for dx:=0 to 3 do col[dx+4*dy]:=col[dx+4*dy-4];
        //Process block:
        k_start:=0;
        e_max:=0;
        for k:=0 to 15 do begin
          oldPixel:=col[k];
          e_:=colDiff(oldPixel,nearestColor(oldPixel));
          if e_>e_max then begin
            e_max:=e_;
            k_start:=k;
          end;
        end;
        err:=BLACK;
        for k in KOCH[k_start] do begin
          oldPixel:=col[k]+err;
          col[k]:=nearestColor(oldPixel);
          err:=oldPixel-col[k];
        end;

        //Write back block:
        for dy:=0 to 3 do if iy+dy<=ym then
        for dx:=0 to 3 do if ix+dx<=xm then
          context^.image[ix+dx,iy+dy]:=col[dx+4*dy];
      end;
    end;

  begin
    //project does not take parameters into account, so we can just pass the current parameters
    case byte(parameters.i1) of
      0: standardAdaptiveColors;
      1: defaultColorTable;
      2: boundsColorTable;
      3: simpleLinearColors;
      4: medianCutColors;
      5: kMeansColorTable;
      6: modifiedMedianCut;
      7: bruteForceColorTable;
      8: bruteForceMedianCut;
    end;
    if colorSource<>nil then dispose(colorSource,destroy);
    case byte(parameters.i2) of
      0: noDither;
      1: floydSteinbergDither;
      2: lineBasedDither;
      3: kochCurveDither;
      4: blockDither_4x4;
      5: jarvisJudiceNinkeDither;
      6: atkinsonDither;
    end;
  end;

INITIALIZATION
registerSimpleOperation(imc_statistic,newParameterDescription('normalize',   pt_none),@normalizeFull_impl);
registerSimpleOperation(imc_statistic,newParameterDescription('normalizeV',  pt_none),@normalizeValue_impl);
registerSimpleOperation(imc_statistic,newParameterDescription('normalizeG',  pt_none),@normalizeGrey_impl);
registerSimpleOperation(imc_statistic,newParameterDescription('compress',pt_float,0)^.setDefaultValue('20'),@compress_impl);
registerSimpleOperation(imc_statistic,newParameterDescription('compress V',pt_float,0)^.setDefaultValue('20'),@compressV_impl);
registerSimpleOperation(imc_statistic,newParameterDescription('compress saturation',pt_float,0)^.setDefaultValue('20'),@compressSat_impl);
registerSimpleOperation(imc_statistic,newParameterDescription('mono',        pt_integer)^.setDefaultValue('10')^.addChildParameterDescription(spa_i0,'Color count',pt_integer,1,255),@mono_impl);
registerSimpleOperation(imc_statistic,newParameterDescription('quantize',    pt_integer)^.setDefaultValue('16')^.addChildParameterDescription(spa_i0,'Color count',pt_integer,2,255),@quantize_impl);
registerSimpleOperation(imc_statistic,newParameterDescription('quantize',    pt_3integers)^.setDefaultValue('16,0,0')
                                                        ^.addChildParameterDescription(spa_i0,'Color count',pt_integer,2,256)
                                                        ^.addEnumChildDescription(spa_i1,'Color mode','Standard adaptive colors',
                                                                                                      'Fixed table 1',
                                                                                                      'Fixed table 2',
                                                                                                      'Monochrome adaptive',
                                                                                                      'Median cut',
                                                                                                      'k-means adaptive',
                                                                                                      'Modified median cut',
                                                                                                      'Brute force',
                                                                                                      'BF/MC')
                                                        ^.addEnumChildDescription(spa_i2,'Dither mode','none',
                                                                                                       'Floyd-Steinberg',
                                                                                                       'Line-Based',
                                                                                                       'Koch-Curve',
                                                                                                       'Block-Dither',
                                                                                                       'Jarvis-Judice-Ninke',
                                                                                                       'Atkinson'),
                                                        @quantizeCustom_impl);

end.

