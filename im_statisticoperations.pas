UNIT im_statisticOperations;
INTERFACE

IMPLEMENTATION
USES imageManipulation,imageContexts,myParams,mypics,myColors,math,myGenerics;
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
  (0,0,0),(255,255,255),(0,255,0),(255,0,0),(0,0,255),(255,255,0),(0,255,255),(255,0,255),
  (128,128,128),(255,128,0),(246,226,129),(28,9,123),(6,133,232),(4,131,47),(250,141,209),(70,254,87),
  (215,0,166),(62,232,170),(221,21,83),(1,104,158),(90,12,46),(254,142,96),(159,253,207),(199,82,197),
  (96,167,54),(73,1,187),(148,232,20),(124,153,254),(114,27,238),(254,206,59),(122,120,0),(26,77,0),
  (245,82,61),(51,67,99),(196,143,158),(11,187,186),(219,199,253),(16,210,109),(252,68,249),(0,148,108),
  (246,44,129),(116,16,139),(130,82,253),(90,105,178),(4,2,73),(116,207,217),(135,69,48),(245,183,168),
  (157,211,124),(2,190,17),(125,177,3),(18,73,209),(255,58,9),(4,245,61),(5,196,241),(186,177,54),
  (255,239,174),(134,65,122),(247,255,84),(251,15,208),(152,3,82),(109,158,207),(128,11,0),(146,252,159),
  (108,116,78),(250,133,254),(5,236,210),(139,182,97),(1,164,151),(98,246,248),(30,254,129),(5,78,48),
  (169,250,97),(252,179,3),(6,49,155),(246,93,123),(3,56,249),(22,127,2),(182,5,37),(245,241,217),
  (119,68,1),(123,45,197),(46,192,146),(11,26,29),(5,172,68),(240,1,124),(14,43,83),(245,19,37),
  (73,226,27),(3,3,171),(165,103,34),(251,186,213),(166,104,162),(195,76,95),(240,34,169),(228,226,20),
  (2,10,216),(252,165,133),(152,245,58),(100,62,162),(201,117,224),(88,125,221),(253,97,185),(238,193,101),
  (183,126,92),(157,202,167),(188,137,40),(78,0,252),(1,121,195),(154,181,253),(123,189,145),(134,9,178),
  (190,253,248),(205,110,0),(82,78,229),(191,2,214),(35,111,79),(52,115,134),(100,201,67),(91,176,174),
  (255,251,48),(73,253,199),(184,61,17),(129,59,85),(74,164,89),(91,53,62),(66,200,240),(84,119,33),
  (229,42,238),(73,14,219),(253,122,60),(168,52,222),(196,145,121),(200,66,59),(81,19,103),(4,109,120),
  (159,213,88),(189,195,197),(66,145,254),(2,94,239),(171,185,21),(78,254,46),(167,67,146),(171,160,192),
  (165,31,250),(87,54,30),(2,213,48),(172,11,110),(43,65,136),(87,142,188),(233,189,38),(250,71,163),
  (254,141,168),(6,254,98),(26,39,0),(15,169,217),(89,159,17),(255,254,140),(77,254,145),(1,107,25),
  (42,169,121),(75,100,104),(254,164,70),(22,48,185),(158,222,225),(173,103,247),(244,71,217),(4,232,164),
  (100,174,118),(121,214,1),(145,143,147),(158,61,177),(223,226,160),(64,0,147),(4,156,25),(80,201,201),
  (4,62,117),(173,247,125),(55,201,23),(245,138,29),(70,151,158),(247,100,21),(19,208,79),(202,14,59),
  (21,213,0),(53,249,229),(24,22,56),(71,134,106),(70,44,162),(158,125,64),(84,0,22),(47,42,28),
  (1,90,75),(183,161,225),(254,59,38),(190,214,141),(78,227,107),(160,133,184),(157,91,225),(248,102,250),
  (119,179,31),(252,207,190),(115,253,118),(197,253,70),(154,234,185),(240,30,105),(176,30,14),(211,22,189),
  (51,165,42),(159,158,74),(214,178,230),(23,199,209),(174,254,7),(40,82,184),(62,0,80),(64,91,42),
  (124,224,62),(121,83,204),(168,30,150),(93,255,4),(248,80,89),(3,155,196),(3,253,28),(53,70,255),
  (250,211,229),(47,113,161),(50,115,252),(250,49,75),(53,215,129),(9,44,213),(93,117,147),(254,129,137),
  (252,227,101),(214,171,116),(91,219,249),(250,105,153),(241,110,100),(52,157,3),(5,166,246),(201,165,84),
  (203,93,112),(93,55,117),(123,12,205),(202,247,44),(79,23,77),(152,251,236),(99,105,58),(50,241,72),
  (35,6,235),(3,230,236),(133,128,89),(77,199,91),(193,85,138),(137,95,114),(66,57,224),(16,0,102));
  VAR colorTable:array of T_rgbFloatColor;
  PROCEDURE standardAdaptiveColors;
    VAR i:longint;
        tree:T_colorTree;
        raw:P_floatColor;
    begin
      raw:=context^.image.rawData;
      tree.create;
      for i:=0 to context^.image.pixelCount-1 do tree.addSample(raw[i]);
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
      raw:=context^.image.rawData;
      for i:=0 to context^.image.pixelCount-1 do begin
        tmp:=raw[i];
        r+=tmp[cc_red];
        g+=tmp[cc_green];
        b+=tmp[cc_blue];
      end;
      i:=context^.image.pixelCount;
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

  FUNCTION medianCutBuckets:T_colorLists;
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
            inc(count,s.count);
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
          maxSpread:=spread[cc_red]+spread[cc_green]+spread[cc_blue];
        end;
      end;

    PROCEDURE split(VAR list:T_colorList; OUT halfList:T_colorList);
      VAR channel:T_colorChannel;
      FUNCTION partition(CONST Left,Right:longint):longint;
        VAR pivot:byte;
            i:longint;
            tmp:T_sample;
        begin
          pivot:=list.sample[Left+random(Right-Left)].color[channel];
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
          popCount+=list.sample[i0].count; inc(i0);
        end;

        setLength(halfList.sample,length(list.sample)-i0);
        for i:=0 to length(halfList.sample)-1 do halfList.sample[i]:=list.sample[i+i0];
        updateSpreads(halfList);

        setLength(list.sample,i0);
        updateSpreads(list);
      end;

    VAR buckets:T_colorLists;
    PROCEDURE splitOneList;
      VAR i:longint;
          toSplit:longint=0;

      begin
        for i:=1 to length(buckets)-1 do if buckets[i].maxSpread>buckets[toSplit].maxSpread then toSplit:=i;
        i:=length(buckets);
        setLength(buckets,i+1);
        split(buckets[toSplit],buckets[i]);
      end;

    PROCEDURE splitAllLists;
      VAR i,i0:longint;
      begin
        i0:=length(buckets);
        setLength(buckets,i0+i0);
        for i:=0 to i0-1 do split(buckets[i],buckets[i0+i]);
        //Check if an empty bucket has been created
        i0:=0;
        for i:=0 to length(buckets)-1 do if length(buckets[i].sample)>0 then begin
          if i0<>i then buckets[i0]:=buckets[i];
          inc(i0);
        end;
        if i0<>length(buckets) then setLength(buckets,i0);
      end;

    FUNCTION firstBucket:T_colorList;
      VAR raw:P_floatColor;
          i,j:longint;
          tmp:T_rgbColor;
          arr:T_arrayOfLongint;
      begin
        raw:=context^.image.rawData;
        setLength(arr,context^.image.pixelCount);
        for i:=0 to context^.image.pixelCount-1 do begin
          tmp:=raw[i];
          arr[i]:=(tmp[cc_red] or longint(tmp[cc_green]) shl 8 or longint(tmp[cc_blue]) shl 16);
        end;
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
        updateSpreads(result);
      end;

    begin
      setLength(buckets,1);
      buckets[0]:=firstBucket;
      while (length(buckets)*2<=parameters.i0) and not context^.cancellationRequested do splitAllLists;
      while (length(buckets)  < parameters.i0) and not context^.cancellationRequested do splitOneList;
      result:=buckets;
    end;

  PROCEDURE medianCutColors;
    VAR k:longint;
        buckets:T_colorLists;
    begin
      buckets:=medianCutBuckets;
      setLength(colorTable,length(buckets));
      for k:=0 to length(buckets)-1 do begin
        colorTable[k]:=averageColor(buckets[k]);
        setLength(buckets[k].sample,0);
      end;
      setLength(buckets,0);
    end;

  PROCEDURE kMeansColorTable;
    VAR allSamples:T_colorList;
        buckets:T_colorLists;
        nextDefaultColor:longint;
    FUNCTION redistributeSamples:boolean;
      VAR i:longint;
          popCount:longint;
          s:T_sample;
          tmp,
          bestDist:double;
          bestIdx :longint;
          previousBucketSizes:T_arrayOfLongint;
      begin
        setLength(previousBucketSizes,length(buckets));
        for i:=0 to length(buckets)-1 do begin
          previousBucketSizes[i]:=length(buckets[i].sample);
          setLength(buckets[i].sample,0);
        end;
        for s in allSamples.sample do begin
          bestDist:=infinity;
          bestIdx :=-1;
          for i:=0 to length(buckets)-1 do begin
            tmp:=subjectiveColDiff(buckets[i].spread,s.color);
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
      buckets:=medianCutBuckets;
      k:=0;
      for i:=0 to length(buckets)-1 do k+=length(buckets[i].sample);
      setLength(allSamples.sample,k);
      k:=0;
      for i:=0 to length(buckets)-1 do for j:=0 to length(buckets[i].sample)-1 do begin
        allSamples.sample[k]:=buckets[i].sample[j];
        inc(k);
      end;
      for i:=0 to length(buckets)-1 do buckets[i].spread:=averageColor(buckets[i]);
      nextDefaultColor:=0;
      i:=0;
      while redistributeSamples and (i<50) and not(context^.cancellationRequested) do inc(i);
      setLength(colorTable,parameters.i0);
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

  FUNCTION nearestColor(CONST pixel:T_rgbFloatColor):T_rgbFloatColor;
    VAR k      :longint;
        kBest  :longint=-1;
        dist   :double;
        minDist:double=infinity;
    begin
      for k:=0 to length(colorTable)-1 do begin
        dist:=subjectiveColDiff(colorTable[k],pixel);
        if dist<minDist then begin
          minDist:=dist;
          kBest  :=k;
        end;
      end;
      result:=colorTable[kBest];
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
        oldPixel:=context^.image[x,y]; newPixel:=nearestColor(oldPixel); context^.image[x,y]:=newPixel; error:=oldPixel-newPixel;
        if x<xm then context^.image.multIncPixel(x+1,y,1,error*(7/16));
        if y<ym then begin
          if x>0  then context^.image.multIncPixel(x-1,y+1,1,error*(3/16));
                       context^.image.multIncPixel(x  ,y+1,1,error*(5/16));
          if x<xm then context^.image.multIncPixel(x  ,y+1,1,error*(1/16));
        end;
      end;
    end;

  PROCEDURE lineBasedDither;
    VAR x,y,xm,ym:longint;
        oldPixel,newPixel,error:T_rgbFloatColor;
    begin
      // 1 -> - and +
      // 0 -> -
      // 2 -> +
      // 3 -> simple
      xm:=context^.image.dimensions.width -1;
      ym:=context^.image.dimensions.height-1;
      for y:=0 to ym do if (y and 3)=1 then for x:=0 to xm do begin
        oldPixel:=context^.image[x,y]; newPixel:=nearestColor(oldPixel); context^.image[x,y]:=newPixel; error:=(oldPixel-newPixel)*0.16666666666666666;
        if x> 0 then context^.image.multIncPixel(x-1,y-1,1,error);
                     context^.image.multIncPixel(x  ,y-1,1,error);
        if x<xm then context^.image.multIncPixel(x+1,y-1,1,error);
        if y<ym then begin
          if x> 0 then context^.image.multIncPixel(x-1,y+1,1,error);
                       context^.image.multIncPixel(x  ,y+1,1,error);
          if x<xm then context^.image.multIncPixel(x+1,y+1,1,error);
        end;
      end;
      if context^.cancellationRequested then exit;
      for y:=0 to ym do case byte(y and 3) of
      0: for x:=0 to xm do begin
           oldPixel:=context^.image[x,y]; newPixel:=nearestColor(oldPixel); context^.image[x,y]:=newPixel; error:=(oldPixel-newPixel)*0.3333333333333333;
           if y>0 then begin
             if x> 0 then context^.image.multIncPixel(x-1,y-1,1,error);
                          context^.image.multIncPixel(x  ,y-1,1,error);
             if x<xm then context^.image.multIncPixel(x+1,y-1,1,error);
           end;
         end;
      2: for x:=0 to xm do begin
           oldPixel:=context^.image[x,y]; newPixel:=nearestColor(oldPixel); context^.image[x,y]:=newPixel; error:=(oldPixel-newPixel)*0.3333333333333333;
           if y<ym then begin
             if x> 0 then context^.image.multIncPixel(x-1,y+1,1,error);
                          context^.image.multIncPixel(x  ,y+1,1,error);
             if x<xm then context^.image.multIncPixel(x+1,y+1,1,error);
           end;
         end;
      end;
      if context^.cancellationRequested then exit;
      for y:=0 to ym do if (y and 3)=3 then for x:=0 to xm do context^.image[x,y]:=nearestColor(context^.image[x,y]);
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
  begin
    case byte(parameters.i1 mod 6) of
      0: standardAdaptiveColors;
      1: defaultColorTable;
      2: boundsColorTable;
      3: simpleLinearColors;
      4: medianCutColors;
      5: kMeansColorTable;
    end;
    case byte(parameters.i2 and 3) of
      0: noDither;
      1: floydSteinbergDither;
      2: lineBasedDither;
      3: kochCurveDither;
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
                                                                                                      'Median cut adaptive',
                                                                                                      'k-means adaptive')
                                                        ^.addEnumChildDescription(spa_i2,'Dither mode','none',
                                                                                                       'Floyd-Steinberg',
                                                                                                       'Line-Based',
                                                                                                       'Koch-Curve'),
                                                        @quantizeCustom_impl);

end.

