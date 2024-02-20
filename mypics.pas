UNIT mypics;
INTERFACE
{$fputype sse3}
USES dos,sysutils,Interfaces,Classes, ExtCtrls, Graphics, IntfGraphics, GraphType,
     math,FPWriteJPEG,FileUtil,
     myParams,
     myGenerics, mySys,
     types,
     myColors,
     pixMaps;

{$define include_interface}

CONST CHUNK_BLOCK_SIZE =64;
TYPE
  T_resizeStyle=(res_exact,
                 res_cropToFill,
                 res_cropRotate,
                 res_fit,
                 res_fitExpand,
                 res_fitRotate,

                 res_exactPixelate,
                 res_cropToFillPixelate,
                 res_cropRotatePixelate,
                 res_fitPixelate,
                 res_fitExpandPixelate,
                 res_fitRotatePixelate,

                 res_dataResize);

  T_structuredHitColor=record
    rest:T_rgbFloatColor;
    antialiasingMask:byte;
  end;

  T_colChunk=object
    lastCalculatedTolerance:single;
    x0,y0:longint;
    width,height:longint;
    col:array[0..CHUNK_BLOCK_SIZE-1,0..CHUNK_BLOCK_SIZE-1] of T_structuredHitColor;
    CONSTRUCTOR create;
    DESTRUCTOR destroy;
    PROCEDURE initForChunk(CONST xRes,yRes,chunkIdx:longint);
    FUNCTION getPicX(CONST localX:longint):longint;
    FUNCTION getPicY(CONST localY:longint):longint;
    FUNCTION markAlias(CONST globalTol:single):boolean;
  end;

  { T_pointList }

  T_pointList=object
    fill:longint;
    points:array[0..31] of record x,y:double; end;
    PROCEDURE clear;
    PROCEDURE add(CONST x,y:double);
  end;

  T_rgbFloatMap=specialize G_pixelMap<T_rgbFloatColor>;
  T_rgbMap=specialize G_pixelMap<T_rgbColor>;
  P_floatColor=^T_rgbFloatColor;

  P_rawImage=^T_rawImage;
  T_rawImage=object(T_rgbFloatMap)
    private
      successfullyLoaded_:boolean;
      //Helper routines:--------------------------------------------------------
      PROCEDURE copyToImage(CONST srcRect:TRect; VAR destImage: TImage);
      //--------------------------------------------------------:Helper routines
    public
      CONSTRUCTOR create(CONST width_,height_:longint);
      CONSTRUCTOR create(CONST fileName:ansistring);
      CONSTRUCTOR create(VAR original:T_rawImage);
      DESTRUCTOR destroy;
      PROPERTY successfullyLoaded:boolean read successfullyLoaded_;
      //Access per pixel:-------------------------------------------------------
      PROPERTY pixel     [x,y:longint]:T_rgbFloatColor read getPixel write setPixel; default;
      PROCEDURE multIncPixel(CONST x,y:longint; CONST factor:single; CONST increment:T_rgbFloatColor);
      PROCEDURE checkedInc(CONST x,y:longint; CONST increment:T_rgbFloatColor);
      //-------------------------------------------------------:Access per pixel
      //Chunk access:-----------------------------------------------------------
      FUNCTION chunksInMap:longint;
      PROCEDURE markChunksAsPending;
      FUNCTION getPendingList(CONST allArePending:boolean):T_arrayOfLongint;
      PROCEDURE copyFromChunk(VAR chunk:T_colChunk);
      FUNCTION getChunkCopy(CONST chunkIndex:longint):T_colChunk;
      //-----------------------------------------------------------:Chunk access
      PROCEDURE clearWithColor(CONST color:T_rgbFloatColor);
      PROCEDURE drawCheckerboard;
      //TImage interface:-------------------------------------------------------
      PROCEDURE copyToImage(VAR destImage: TImage);
      PROCEDURE copyFromImage(VAR srcImage: TImage);
      //-------------------------------------------------------:TImage interface
      //File interface:---------------------------------------------------------
      PROCEDURE saveToFile(CONST fileName:ansistring);
      PROCEDURE loadFromFile(CONST fileName:ansistring);
      PROCEDURE saveJpgWithSizeLimit(CONST fileName:ansistring; CONST sizeLimit:SizeInt);
      FUNCTION getJpgFileData(CONST quality:longint=100):ansistring;
      //---------------------------------------------------------:File interface
      //Geometry manipulations:-------------------------------------------------
      PROCEDURE resize(CONST tgtDim:T_imageDimensions; CONST resizeStyle:T_resizeStyle; CONST highQuality:boolean);
      PROCEDURE zoom(CONST factor:double; CONST highQuality:boolean);
      //-------------------------------------------------:Geometry manipulations
      //Statistic accessors:----------------------------------------------------
      FUNCTION histogram:T_compoundHistogram;
      FUNCTION histogramHSV:T_compoundHistogram;
      //----------------------------------------------------:Statistic accessors
      PROCEDURE quantize(CONST numberOfColors:longint);
      FUNCTION directionMap(CONST relativeSigma:double):T_rawImage;
      PROCEDURE lagrangeDiffusion(CONST relativeGradSigma,relativeBlurSigma:double; CONST stopRequested:F_stopRequested=nil);
      PROCEDURE lagrangeDiffusion(VAR dirMap:T_rawImage; CONST relativeBlurSigma:double; CONST changeDirection:boolean=true; CONST stopRequested:F_stopRequested=nil);
      PROCEDURE radialBlur(CONST relativeBlurSigma,relativeCenterX,relativeCenterY:double; CONST stopRequested:F_stopRequested=nil);
      PROCEDURE rotationalBlur(CONST relativeBlurSigma,relativeCenterX,relativeCenterY:double; CONST stopRequested:F_stopRequested=nil);
      PROCEDURE shine;
      PROCEDURE sharpen(CONST relativeSigma,factor:double; CONST stopRequested:F_stopRequested=nil);
      PROCEDURE prewittEdges;
      PROCEDURE variance(CONST relativeSigma:double);
      PROCEDURE medianFilter(CONST relativeSigma:double);
      PROCEDURE modalFilter(CONST relativeSigma:double);
      PROCEDURE sketch(CONST cover,relativeDirMapSigma,density,tolerance:double; CONST stopRequested:F_stopRequested=nil);
      PROCEDURE myFilter(CONST thresholdDistParam,param:double; CONST stopRequested:F_stopRequested=nil);
      PROCEDURE drip(CONST diffusiveness,range:double);
      FUNCTION rgbaSplit(CONST transparentColor:T_rgbFloatColor):T_rawImage;
      PROCEDURE halftone(CONST scale:single; CONST param:longint);
      PROCEDURE rotate(CONST angleInDegrees:double; CONST highQuality:boolean);
      PROCEDURE copyFromImageWithOffset(VAR image:T_rawImage; CONST xOff,yOff:longint);
      FUNCTION simpleSubPixel(CONST x,y:double):T_rgbFloatColor;
      FUNCTION subPixelAverage(CONST points:T_pointList):T_rgbFloatColor;
      FUNCTION subPixelBoxAvg(CONST x0,x1,y0,y1:double):T_rgbFloatColor;
  end;

F_displayErrorFunction=PROCEDURE(CONST s:ansistring);

VAR compressionQualityPercentage:longint=100;
CONST EMPTY_POINT_LIST:T_pointList=(fill:0);

IMPLEMENTATION
USES darts;
VAR globalFileLock:TRTLCriticalSection;
CONSTRUCTOR T_colChunk.create;
  begin end;

PROCEDURE T_colChunk.initForChunk(CONST xRes,yRes,chunkIdx:longint);
  VAR i,j:longint;
  begin
    x0:=0;
    y0:=0;
    for i:=0 to chunkIdx-1 do begin
      inc(x0,CHUNK_BLOCK_SIZE);
      if x0>=xRes then begin
        x0:=0;
        inc(y0,CHUNK_BLOCK_SIZE);
      end;
    end;
    width :=xRes-x0; if width >CHUNK_BLOCK_SIZE then width :=CHUNK_BLOCK_SIZE;
    height:=yRes-y0; if height>CHUNK_BLOCK_SIZE then height:=CHUNK_BLOCK_SIZE;
    for i:=0 to CHUNK_BLOCK_SIZE-1 do for j:=0 to CHUNK_BLOCK_SIZE-1 do with col[i,j] do begin
      rest:=BLACK;
      antialiasingMask:=0;
    end;
  end;

DESTRUCTOR T_colChunk.destroy;
  begin
  end;

FUNCTION T_colChunk.getPicX(CONST localX:longint):longint;
  begin
    result:=localX+x0;
  end;

FUNCTION T_colChunk.getPicY(CONST localY:longint):longint;
  begin
    result:=localY+y0;
  end;

{$PUSH}{$OPTIMIZATION OFF}
FUNCTION combinedColor(CONST struc:T_structuredHitColor):T_rgbFloatColor;
  begin
    with struc do if antialiasingMask<2
    then result:=rest
    else result:=rest*(0.5/(antialiasingMask and 254));
  end;
{$POP}

FUNCTION T_colChunk.markAlias(CONST globalTol:single):boolean;
  VAR i,j,i2,j2:longint;
      localRefFactor:single;
      localTol:single;
      localError:single;
      tempColor:array[0..CHUNK_BLOCK_SIZE-1,0..CHUNK_BLOCK_SIZE-1] of T_rgbFloatColor;

  FUNCTION getErrorAt(CONST i,j:longint):double;
    VAR c:array[-1..1,-1..1] of T_rgbFloatColor;
        di,dj,ki,kj:longint;
    begin
      if (height<3) or (width<3) then exit(1E6);
      for di:=-1 to 1 do for dj:=-1 to 1 do begin
        ki:=di+i; if ki<0 then ki:=0-ki else if ki>width-1  then ki:=2*(width -1)-ki;
        kj:=dj+j; if kj<0 then kj:=0-kj else if kj>height-1 then kj:=2*(height-1)-kj;
        c[di,dj]:=tempColor[ki,kj];
      end;
      result:=calcErr(c[-1,-1],c[0,-1],c[1,-1],
                      c[-1, 0],c[0, 0],c[1, 0],
                      c[-1,+1],c[0,+1],c[1,+1]);
    end;

  begin
    result:=false;
    for i:=0 to width-1 do for j:=0 to height-1 do tempColor[i,j]:=combinedColor(col[i,j]);

    for i:=0 to width-1 do for j:=0 to height-1 do if col[i,j].antialiasingMask<64 then begin
      localRefFactor:=(col[i,j].antialiasingMask and 254)/254;
      localTol:=(1+localRefFactor*localRefFactor)*globalTol;
      localError:=getErrorAt(i,j);
      if localError>localTol then begin
        for i2:=i-1 to i+1 do if (i2>=0) and (i2<width) then
        for j2:=j-1 to j+1 do if (j2>=0) and (j2<height) and not(odd(col[i2,j2].antialiasingMask)) and (col[i2,j2].antialiasingMask<254) then begin
          inc(col[i2,j2].antialiasingMask);
          result:=true;
        end;
      end;
    end;
  end;

{ T_pointList }

PROCEDURE T_pointList.clear;
  begin
    fill:=0;
  end;

PROCEDURE T_pointList.add(CONST x, y: double);
  begin
    points[fill].x:=x;
    points[fill].y:=y;
    inc(fill);
  end;

CONSTRUCTOR T_rawImage.create(CONST width_, height_: longint);
  begin
    inherited create(width_,height_);
    successfullyLoaded_:=false;
  end;

CONSTRUCTOR T_rawImage.create(CONST fileName: ansistring);
  begin
    inherited create(1,1);
    successfullyLoaded_:=false;
    loadFromFile(fileName);
  end;

CONSTRUCTOR T_rawImage.create(VAR original: T_rawImage);
  begin
    inherited create(1,1);
    successfullyLoaded_:=false;
    copyFromPixMap(original);
  end;

DESTRUCTOR T_rawImage.destroy;
  begin
    inherited destroy;
  end;

PROCEDURE T_rawImage.copyToImage(CONST srcRect: TRect; VAR destImage: TImage);
  VAR ScanLineImage,                 //image with representation as in T_24BitImage
      tempIntfImage: TLazIntfImage;  //image with representation as in TBitmap
      ImgFormatDescription: TRawImageDescription;
      x,y:longint;
      pc:T_rgbColor;
      pix:PByte;
  begin
    ScanLineImage:=TLazIntfImage.create(srcRect.Right-srcRect.Left,srcRect.Bottom-srcRect.top);
    try
      ImgFormatDescription.Init_BPP24_B8G8R8_BIO_TTB(srcRect.Right-srcRect.Left,srcRect.Bottom-srcRect.top);
      ImgFormatDescription.ByteOrder:=riboMSBFirst;
      ScanLineImage.DataDescription:=ImgFormatDescription;
      for y:=0 to srcRect.Bottom-srcRect.top-1 do begin
        pix:=ScanLineImage.GetDataLineStart(y);
        for x:=0 to srcRect.Right-srcRect.Left-1 do begin
          pc:=getPixel(srcRect.Left+x,srcRect.top+y);
          move(pc,(pix+3*x)^,3);
        end;
      end;
      destImage.picture.Bitmap.setSize(srcRect.Right-srcRect.Left,srcRect.Bottom-srcRect.top);
      tempIntfImage:=destImage.picture.Bitmap.CreateIntfImage;
      tempIntfImage.CopyPixels(ScanLineImage);
      destImage.picture.Bitmap.LoadFromIntfImage(tempIntfImage);
      tempIntfImage.free;
    finally
      ScanLineImage.free;
    end;
  end;

PROCEDURE T_rawImage.copyToImage(VAR destImage: TImage);
  begin
    copyToImage(rect(0,0,dim.width,dim.height),destImage);
  end;

PROCEDURE T_rawImage.copyFromImage(VAR srcImage: TImage);
  VAR x,y:longint;
      tempIntfImage,
      ScanLineImage: TLazIntfImage;
      ImgFormatDescription: TRawImageDescription;
      pc:T_rgbColor;
      pix:PByte;

  begin
    initialize(pc);
    resize(imageDimensions(srcImage.picture.width,srcImage.picture.height),res_dataResize,false);

    ScanLineImage:=TLazIntfImage.create(dim.width,dim.height);
    ImgFormatDescription.Init_BPP24_B8G8R8_BIO_TTB(dim.width,dim.height);
    ImgFormatDescription.ByteOrder:=riboMSBFirst;
    ScanLineImage.DataDescription:=ImgFormatDescription;
    tempIntfImage:=srcImage.picture.Bitmap.CreateIntfImage;
    ScanLineImage.CopyPixels(tempIntfImage);
    for y:=0 to dim.height-1 do begin
      pix:=ScanLineImage.GetDataLineStart(y);
      for x:=0 to dim.width-1 do begin
        move((pix+3*x)^,pc,3);
        setPixel(x,y,pc);
      end;
    end;
    ScanLineImage.free;
    tempIntfImage.free;
  end;

PROCEDURE T_rawImage.multIncPixel(CONST x,y:longint; CONST factor:single; CONST increment:T_rgbFloatColor);
  VAR k:longint;
  begin
    k:=x+y*dim.width;
    data[k]:=data[k]*factor+increment;
  end;

PROCEDURE T_rawImage.checkedInc(CONST x,y:longint; CONST increment:T_rgbFloatColor);
  begin
    if (x<0) or (x>=dim.width) or (y<0) or (y>=dim.height) then exit;
    data[x+y*dim.width]+=increment;
  end;

FUNCTION T_rawImage.chunksInMap: longint;
  VAR xChunks,yChunks:longint;
  begin
    xChunks:=dim.width  div CHUNK_BLOCK_SIZE; if xChunks*CHUNK_BLOCK_SIZE<dim.width  then inc(xChunks);
    yChunks:=dim.height div CHUNK_BLOCK_SIZE; if yChunks*CHUNK_BLOCK_SIZE<dim.height then inc(yChunks);
    result:=xChunks*yChunks;
  end;

PROCEDURE T_rawImage.markChunksAsPending;
  VAR x,y:longint;
  begin
    for y:=0 to dim.height-1 do for x:=0 to dim.width-1 do
      if ((x and 63) in [0,63]) or ((y and 63) in [0,63]) or (odd(x) xor odd(y)) and (((x and 63) in [21,42]) or ((y and 63) in [21,42]))
      then pixel[x,y]:=WHITE
      else pixel[x,y]:=BLACK;
  end;

FUNCTION T_rawImage.getPendingList(CONST allArePending:boolean): T_arrayOfLongint;
  VAR xChunks,yChunks:longint;
      x,y,cx,cy,i:longint;
      isPending:array of array of boolean=();
  begin
    randomize;
    xChunks:=dim.width  div CHUNK_BLOCK_SIZE; if xChunks*CHUNK_BLOCK_SIZE<dim.width  then inc(xChunks);
    yChunks:=dim.height div CHUNK_BLOCK_SIZE; if yChunks*CHUNK_BLOCK_SIZE<dim.height then inc(yChunks);

    if allArePending then begin
      setLength(result,xChunks*yChunks);
      for i:=0 to length(result)-1 do result[i]:=i;
    end else begin
      setLength(isPending,xChunks);
      for cx:=0 to length(isPending)-1 do begin
        setLength(isPending[cx],yChunks);
        for cy:=0 to length(isPending[cx])-1 do isPending[cx,cy]:=true;
      end;
      //scan:-----------------------------------------------------
      for y:=0 to dim.height-1 do begin
        cy:=y div CHUNK_BLOCK_SIZE;
        for x:=0 to dim.width-1 do begin
          cx:=x div CHUNK_BLOCK_SIZE;
          if ((x and 63) in [0,63]) or ((y and 63) in [0,63]) or (odd(x) xor odd(y)) and (((x and 63) in [21,42]) or ((y and 63) in [21,42]))
          then isPending[cx,cy]:=isPending[cx,cy] and (pixel[x,y]=WHITE)
          else isPending[cx,cy]:=isPending[cx,cy] and (pixel[x,y]=BLACK);
        end;
      end;
      //-----------------------------------------------------:scan
      //transform boolean mask to int array:----------------------
      initialize(result);
      setLength(result,0);
      for cy:=0 to length(isPending[0])-1 do
      for cx:=length(isPending)-1 downto 0 do if isPending[cx,cy] then begin
        setLength(result,length(result)+1);
        result[length(result)-1]:=cx+xChunks*cy;
      end;
      for cx:=0 to length(isPending)-1 do setLength(isPending[cx],0);
      setLength(isPending,0);
      //----------------------:transform boolean mask to int array
    end;
    //scramble result:------------------------------------------
    {$ifndef debugMode}
    for i:=0 to length(result) shr 2-1 do begin
      cx:=random(length(result));
      repeat cy:=random(length(result)) until cx<>cy;
      x:=result[cx]; result[cx]:=result[cy]; result[cy]:=x;
    end;
    {$endif}
  end;

PROCEDURE T_rawImage.copyFromChunk(VAR chunk: T_colChunk);
  VAR i,j:longint;
  begin
    for j:=0 to chunk.height-1 do for i:=0 to chunk.width-1 do with chunk.col[i,j] do
      pixel[chunk.getPicX(i),chunk.getPicY(j)]:=combinedColor(chunk.col[i,j]);
  end;

FUNCTION T_rawImage.getChunkCopy(CONST chunkIndex:longint):T_colChunk;
  VAR i,j:longint;
  begin
    result.initForChunk(dimensions.width,dimensions.height,chunkIndex);
    for j:=0 to result.height-1 do for i:=0 to result.width-1 do with result.col[i,j] do begin
      rest:=pixel[result.getPicX(i),result.getPicY(j)];
      antialiasingMask:=0;
    end;
  end;

PROCEDURE T_rawImage.clearWithColor(CONST color:T_rgbFloatColor);
  VAR i:longint;
  begin
    for i:=0 to pixelCount-1 do data[i]:=color;
  end;

PROCEDURE T_rawImage.drawCheckerboard;
  CONST floatGrey:array[false..true] of T_rgbFloatColor=((0.6,0.6,0.6),(0.4,0.4,0.4));
  VAR i,j:longint;
  begin
    for j:=0 to dim.height-1 do for i:=0 to dim.width-1 do setPixel(i,j,floatGrey[odd(i shr 5) xor odd(j shr 5)]);
  end;

PROCEDURE T_rawImage.saveToFile(CONST fileName: ansistring);
  PROCEDURE storeDump;
    VAR handle:file of byte;
    begin
      assign(handle,fileName);
      rewrite(handle);
      BlockWrite(handle,dim.width ,sizeOf(longint));
      BlockWrite(handle,dim.height,sizeOf(longint));
      BlockWrite(handle,PByte(data)^,dataSize);
      close(handle);
    end;

  VAR ext:string;
      storeImg:TImage;
      Jpeg:TFPWriterJPEG;
      img:TLazIntfImage;
  begin
    ForceDirectories(extractFilePath(expandFileName(fileName)));
    ext:=uppercase(extractFileExt(fileName));
    if (ext=JPG_EXT) or (ext=PNG_EXT) or (ext=BMP_EXT) then begin
      enterCriticalSection(globalFileLock);
      storeImg:=TImage.create(nil);
      storeImg.SetInitialBounds(0,0,dim.width,dim.height);
      copyToImage(storeImg);
      if ext=PNG_EXT then storeImg.picture.PNG.saveToFile(fileName) else
      if ext=BMP_EXT then storeImg.picture.Bitmap.saveToFile(fileName)
                 else begin
        Jpeg:=TFPWriterJPEG.create;
        Jpeg.CompressionQuality:=100;
        img:=storeImg.picture.Bitmap.CreateIntfImage;
        img.saveToFile(fileName,Jpeg);
        img.free;
        Jpeg.free;
      end;
      storeImg.free;
      leaveCriticalSection(globalFileLock);
    end else if ext=RAW_EXT then storeDump
    else raise Exception.create('Usupported image format "'+ext+'"');
  end;

PROCEDURE T_rawImage.loadFromFile(CONST fileName: ansistring);
  VAR useFilename:ansistring;
  PROCEDURE restoreDump;
    VAR handle:file of byte;
    begin
      freeMem(data,dataSize);
      assign(handle,useFilename);
      reset(handle);
      BlockRead(handle,dim.width ,sizeOf(longint));
      BlockRead(handle,dim.height,sizeOf(longint));
      getMem(data,dataSize);
      BlockRead(handle,PByte(data)^,dataSize);
      close(handle);
    end;

  VAR ext:string;
      reStoreImg:TImage;
  begin
    if fileExists(fileName) then useFilename:=fileName
    else begin
      writeln(stdErr,'Image ',fileName,' cannot be loaded because it does not exist');
      successfullyLoaded_:=false;
      exit;
    end;
    ext:=uppercase(extractFileExt(useFilename));
    if (ext=JPG_EXT) or (ext=JPEG_EXT) or (ext=PNG_EXT) or (ext=BMP_EXT) then begin
      enterCriticalSection(globalFileLock);
      reStoreImg:=TImage.create(nil);
      leaveCriticalSection(globalFileLock);
      try
        reStoreImg.SetInitialBounds(0,0,10000,10000);
        if ext=PNG_EXT then reStoreImg.picture.PNG   .loadFromFile(useFilename) else
        if ext=BMP_EXT then reStoreImg.picture.Bitmap.loadFromFile(useFilename)
                       else reStoreImg.picture.Jpeg  .loadFromFile(useFilename);
        reStoreImg.SetBounds(0,0,reStoreImg.picture.width,reStoreImg.picture.height);
        copyFromImage(reStoreImg);
        successfullyLoaded_:=true;
      finally
        reStoreImg.free;
      end;
    end else restoreDump;
  end;

PROCEDURE T_rawImage.saveJpgWithSizeLimit(CONST fileName:ansistring; CONST sizeLimit:SizeInt);
  VAR ext:string;
      storeImg:TImage;

  FUNCTION filesize(name:string):longint;
    VAR s:TSearchRec;
    begin
      if findFirst(name,faAnyFile,s)=0
        then result:=s.size
        else result:=0;
      findClose(s);
    end;

  VAR quality:longint;
      sizes:array[1..100] of longint;

  FUNCTION saveAtQuality(CONST quality:longint; CONST saveToFile:boolean):longint;
    VAR Jpeg:TFPWriterJPEG;
        img:TLazIntfImage;
        stream:TMemoryStream;
    begin
      Jpeg:=TFPWriterJPEG.create;
      Jpeg.CompressionQuality:=quality;
      img:=storeImg.picture.Bitmap.CreateIntfImage;
      if saveToFile then begin
        img.saveToFile(fileName,Jpeg);
        result:=filesize(fileName);
      end else begin
        stream:=TMemoryStream.create;
        img.saveToStream(stream,Jpeg);
        result:=stream.position;
        stream.free;
      end;
      img.free;
      Jpeg.free;
    end;

  FUNCTION getSizeAt(CONST quality:longint):longint;
    begin
      if quality>100 then exit(getSizeAt(100));
      if quality<1   then exit(getSizeAt(  1));
      if sizes[quality]<0 then sizes[quality]:=saveAtQuality(quality,false);
      result:=sizes[quality];
    end;

  begin
    ext:=uppercase(extractFileExt(fileName));
    if (ext<>JPG_EXT) and (ext<>'.JPEG') then raise Exception.create('Saving with size limit is only possible in JPEG format.');
    if sizeLimit=0 then begin
      saveJpgWithSizeLimit(fileName,round(1677*diagonal));
      exit();
    end;
    ForceDirectories(extractFilePath(expandFileName(fileName)));
    enterCriticalSection(globalFileLock);
    storeImg:=TImage.create(nil);
    storeImg.SetInitialBounds(0,0,dim.width,dim.height);
    copyToImage(storeImg);
    for quality:=1 to 100 do sizes[quality]:=-1;
    quality:=100;
    while (quality>  1) and (getSizeAt(quality)>sizeLimit) do dec(quality,64); if (quality<  1) then quality:=  1;
    while (quality<100) and (getSizeAt(quality)<sizeLimit) do inc(quality,32); if (quality>100) then quality:=100;
    while (quality>  1) and (getSizeAt(quality)>sizeLimit) do dec(quality,16); if (quality<  1) then quality:=  1;
    while (quality<100) and (getSizeAt(quality)<sizeLimit) do inc(quality, 8); if (quality>100) then quality:=100;
    while (quality>  1) and (getSizeAt(quality)>sizeLimit) do dec(quality, 4); if (quality<  1) then quality:=  1;
    while (quality<100) and (getSizeAt(quality)<sizeLimit) do inc(quality, 2); if (quality>100) then quality:=100;
    while (quality>  1) and (getSizeAt(quality)>sizeLimit) do dec(quality   );
    saveAtQuality(quality,true);
    storeImg.free;
    leaveCriticalSection(globalFileLock);
  end;

  FUNCTION T_rawImage.getJpgFileData(CONST quality:longint=100):ansistring;
    VAR Jpeg:TFPWriterJPEG;
        img:TLazIntfImage;
        stream:TStringStream;
        storeImg:TImage;
    begin
      storeImg:=TImage.create(nil);
      storeImg.SetInitialBounds(0,0,dim.width,dim.height);
      copyToImage(storeImg);
      Jpeg:=TFPWriterJPEG.create;
      Jpeg.CompressionQuality:=quality;
      img:=storeImg.picture.Bitmap.CreateIntfImage;
      stream:= TStringStream.create('');
      img.saveToStream(stream,Jpeg);
      img.free;
      Jpeg.free;
      storeImg.free;
      result:=stream.DataString;
      stream.free;
    end;

PROCEDURE T_rawImage.resize(CONST tgtDim:T_imageDimensions; CONST resizeStyle: T_resizeStyle; CONST highQuality:boolean);
  VAR srcRect,destRect:TRect;
      dx,dy:longint;
      destDim:T_imageDimensions;
      doRotate:boolean=false;
  PROCEDURE resizeViaTImage;
    VAR srcImage,destImage:TImage;
    begin
      srcImage:=TImage.create(nil);
      srcImage.SetInitialBounds(0,0,srcRect.Right-srcRect.Left,srcRect.Bottom-srcRect.top);
      copyToImage(srcRect,srcImage);
      destImage:=TImage.create(nil);
      destImage.SetInitialBounds(destRect.Left,destRect.top,destRect.Right,destRect.Bottom);
      if resizeStyle in [res_exactPixelate,
                         res_cropToFillPixelate,
                         res_cropRotatePixelate,
                         res_fitPixelate,
                         res_fitExpandPixelate,
                         res_fitRotatePixelate]
      then begin
        destImage.AntialiasingMode       :=amOff;
        destImage.Canvas.AntialiasingMode:=amOff;
      end else begin
        destImage.AntialiasingMode       :=amOn;
        destImage.Canvas.AntialiasingMode:=amOn;
      end;
      destImage.Canvas.StretchDraw(destRect,srcImage.picture.Graphic);
      srcImage.free;
      copyFromImage(destImage);
      destImage.free;
    end;

  PROCEDURE resizeViaRawImage;
    VAR temp:T_rawImage;
        x,y:longint;
        //col: T_rgbFloatColor;
        //points:T_pointList;
    begin
      temp.create(self);
      destDim:=imageDimensions(destRect.width,destRect.height);
      inherited resize(destDim);
      clearWithColor(BLACK);
      for y:=destRect.top to destRect.Bottom-1 do
      for x:=destRect.Left to destRect.Right-1 do begin
//        points.clear;
//        for k:=0 to 31 do points.add(srcRect.Left+srcRect.width /destRect.width *(x-darts_delta[k,0]),
//                                     srcRect.top +srcRect.height/destRect.height*(y-darts_delta[k,1]));
        pixel[x,y]:=temp.subPixelBoxAvg(
          srcRect.Left+srcRect.width /destRect.width *(x-0.5),
          srcRect.Left+srcRect.width /destRect.width *(x+0.5),
          srcRect.top +srcRect.height/destRect.height*(y-0.5),
          srcRect.top +srcRect.height/destRect.height*(y+0.5));  //temp.subPixelAverage(points);
      end;
      temp.destroy;
    end;

  begin
    case resizeStyle of
      res_exact,res_exactPixelate,res_dataResize: begin
        if tgtDim=dim then exit;
        srcRect:=dim.toRect;
        destRect:=tgtDim.toRect;
      end;
      res_fit,res_fitExpand,res_fitPixelate,res_fitExpandPixelate: begin
        srcRect:=dim.toRect;
        destRect:=tgtDim.getFittingRectangle(dim.width/dim.height).toRect;
      end;
      res_fitRotate, res_cropRotate, res_fitRotatePixelate, res_cropRotatePixelate: begin
        destRect:=tgtDim.getFittingRectangle(dim.width/dim.height).toRect;
        srcRect :=tgtDim.getFittingRectangle(dim.height/dim.width).toRect;
        if srcRect.Right*srcRect.Bottom>destRect.Right*destRect.Bottom then begin
          doRotate:=true;
          destRect:=srcRect;
          srcRect:=rect(0,0,dim.height,dim.width);
        end else srcRect:=dim.toRect;
        if resizeStyle in [res_cropRotate,res_cropRotatePixelate] then begin
          destRect:=tgtDim.toRect;
          if doRotate then begin
            dx:=round(dim.height-dim.width*tgtDim.width/tgtDim.height); if dx<0 then dx:=0;
            dy:=round(dim.width-dim.height*tgtDim.height/tgtDim.width); if dy<0 then dy:=0;
            srcRect:=rect(dx shr 1,dy shr 1,dim.height+(dx shr 1)-dx,dim.width+(dy shr 1)-dy);
          end else begin
            dx:=round(dim.width-dim.height*tgtDim.width/tgtDim.height); if dx<0 then dx:=0;
            dy:=round(dim.height-dim.width*tgtDim.height/tgtDim.width); if dy<0 then dy:=0;
            srcRect:=rect(dx shr 1,dy shr 1,dim.width+(dx shr 1)-dx,dim.height+(dy shr 1)-dy);
          end;
        end;
      end;
      res_cropToFill,res_cropToFillPixelate: begin
        destRect:=tgtDim.toRect;
        //(xRes-dx)/(dim.height-dy)=newWidth/newHeight
        //dy=0 => dx=xRes-dim.height*newWidth/newHeight
        //dx=0 => dy=dim.height-xRes*newHeight/newWidth
        dx:=round(dim.width-dim.height*tgtDim.width/tgtDim.height); if dx<0 then dx:=0;
        dy:=round(dim.height-dim.width*tgtDim.height/tgtDim.width); if dy<0 then dy:=0;
        srcRect:=rect(dx shr 1,dy shr 1,dim.width+(dx shr 1)-dx,dim.height+(dy shr 1)-dy);
      end;
    end;
    if doRotate then rotLeft;
    if resizeStyle=res_dataResize then begin
      destDim:=tgtDim;
      inherited resize(destDim);
    end else if highQuality and (resizeStyle in [res_exact,res_cropToFill,res_cropRotate,res_fit,res_fitExpand,res_fitRotate])
    then resizeViaRawImage
    else resizeViaTImage;
    if resizeStyle in [res_fitExpand,res_fitExpandPixelate] then begin
      destDim.width :=tgtDim.width -dim.width ; dx:=-(destDim.width  shr 1); inc(destDim.width ,dx+dim.width );
      destDim.height:=tgtDim.height-dim.height; dy:=-(destDim.height shr 1); inc(destDim.height,dy+dim.height);
      cropAbsolute(dx,destDim.width,dy,destDim.height);
    end;
  end;

PROCEDURE T_rawImage.zoom(CONST factor:double; CONST highQuality:boolean);
  VAR oldDim:T_imageDimensions;
      x0,x1,y0,y1:longint;
      cx,cy:double;
      temp:T_rawImage;
      invFactor:double;
  FUNCTION hqPixel(CONST ix,iy:longint):T_rgbFloatColor;
    VAR k:longint;
        points:T_pointList;
    begin
      points.clear;
      for k:=0 to 31 do points.add((ix-cx)*invFactor+cx+darts_delta[k,0],
                                   (iy-cy)*invFactor+cy+darts_delta[k,1]);
      result:=temp.subPixelAverage(points);
    end;

  VAR x,y:longint;
  begin
    if highQuality then begin
      invFactor:=1/factor;
      temp.create(self);
      cx:=dim.width/2;
      cy:=dim.height/2;
      for y:=0 to dim.height-1 do for x:=0 to dim.width-1 do pixel[x,y]:=hqPixel(x,y);
      temp.destroy;
    end else begin
      oldDim:=dim;
      if factor>1 then begin
        crop(0.5-0.5/factor,0.5+0.5/factor,
             0.5-0.5/factor,0.5+0.5/factor);
        resize(oldDim,res_exact,highQuality);
      end else begin
        //new size=old size*factor
        resize(imageDimensions(round(oldDim.width *factor),
                               round(oldDim.height*factor)),res_exact,highQuality);
        //x0=round(rx0                               *dim.width)
        //  =round((0.5-0.5/ factor                 )*dim.width)
        //  =round((0.5-0.5/(dim.width/oldDim.width))*dim.width)
        //  =round(0.5*dim.width-0.5*oldDim.width);
        x0:=dim.width shr 1-oldDim.width shr 1;
        x1:= oldDim.width+x0;
        y0:=dim.height shr 1-oldDim.height shr 1;
        y1:= oldDim.height+y0;
        cropAbsolute(x0,x1,y0,y1);
      end;
    end;
  end;

FUNCTION T_rawImage.histogram: T_compoundHistogram;
  VAR i:longint;
  begin
    result.create;
    for i:=0 to pixelCount-1 do result.putSample(data[i]);
  end;

FUNCTION T_rawImage.histogramHSV: T_compoundHistogram;
  VAR i:longint;
      hsv:T_hsvColor;
  begin
    result.create;
    for i:=0 to pixelCount-1 do begin
      hsv:=data[i];
      result.putSample(rgbColor(hsv[hc_hue],hsv[hc_saturation],hsv[hc_value]));
    end;
  end;

PROCEDURE T_rawImage.quantize(CONST numberOfColors:longint);
  VAR i:longint;
      tree:T_colorTree;
  begin
    tree.create;
    for i:=0 to pixelCount-1 do tree.addSample(data[i]);
    tree.finishSampling(numberOfColors);
    for i:=0 to pixelCount-1 do data[i]:=tree.getQuantizedColor(data[i]);
    tree.destroy;
  end;

FUNCTION T_rawImage.directionMap(CONST relativeSigma:double):T_rawImage;
  VAR x,y:longint;

  FUNCTION normalAt(x,y:longint):T_rgbFloatColor;
    VAR dx,dy:longint;
        channel:T_colorChannel;
        n:array[-1..1,-1..1] of T_rgbFloatColor;
        w :array [0..1] of double;
    begin
      //fill stencil:--------------------------------------------//
      for dy:=-1 to 1 do for dx:=-1 to 1 do                      //
      if (y+dy>=0) and (y+dy<dim.height) and (x+dx>=0) and (x+dx<dim.width)
        then n[dx,dy]:=getPixel(x+dx,(y+dy))                     //
        else n[dx,dy]:=getPixel(x   , y    );                    //
      //----------------------------------------------:fill stencil
      result:=BLACK;
      for channel in RGB_CHANNELS do begin
        w[0]:=n[ 1,-1][channel]+3*n[ 1,0][channel]+n[ 1,1][channel]
             -n[-1,-1][channel]-3*n[-1,0][channel]-n[-1,1][channel];
        w[1]:=n[-1, 1][channel]+3*n[0, 1][channel]+n[1, 1][channel]
             -n[-1,-1][channel]-3*n[0,-1][channel]-n[1,-1][channel];
        result[cc_blue ]:=1/(1E-6+w[0]*w[0]+w[1]*w[1]);
        result[cc_red  ]:=result[cc_red  ]+result[cc_blue]*(w[0]*w[0]-w[1]*w[1]);
        result[cc_green]:=result[cc_green]+result[cc_blue]*2*w[0]*w[1];
      end;
      result[cc_blue]:=0;
    end;

  FUNCTION normedDirection(CONST d:T_rgbFloatColor):T_rgbFloatColor;
    begin
      result[cc_blue ]:=arctan2(d[cc_green],d[cc_red])/2;
      result[cc_red  ]:=-sin(result[cc_blue]);
      result[cc_green]:= cos(result[cc_blue]);
      result[cc_blue ]:=0;
    end;

  begin
    result.create(dim.width,dim.height);
    for y:=0 to dim.height-1 do for x:=0 to dim.width-1 do result[x,y]:=normalAt(x,y);
    result.blur(relativeSigma,relativeSigma);
    for x:=0 to result.pixelCount-1 do result.data[x]:=normedDirection(result.data[x]);
  end;

PROCEDURE T_rawImage.lagrangeDiffusion(CONST relativeGradSigma,relativeBlurSigma:double; CONST stopRequested:F_stopRequested=nil);
  VAR dirMap:T_rawImage;
  begin
    dirMap:=directionMap(relativeGradSigma);
    lagrangeDiffusion(dirMap,relativeBlurSigma,true,stopRequested);
    dirMap.destroy;
  end;

PROCEDURE T_rawImage.lagrangeDiffusion(VAR dirMap:T_rawImage; CONST relativeBlurSigma:double; CONST changeDirection:boolean=true; CONST stopRequested:F_stopRequested=nil);
  VAR output:T_rawImage;
      kernel:T_arrayOfDouble;
      x,y,i,k,ix,iy:longint;
      pos,dir:T_rgbFloatColor;
      colSum:T_rgbFloatColor;
      wgtSum:double;
      shouldStop:F_stopRequested;

  PROCEDURE step; inline;
    VAR d:T_rgbFloatColor;
    begin
      if changeDirection then begin d:=dirMap[ix,iy]; if d[cc_red]*dir[cc_red]+d[cc_green]*dir[cc_green] > 0 then dir:=d else dir:=d*(-1); end;
      pos:=pos+dir;
      ix:=round(pos[cc_red]);
      iy:=round(pos[cc_green]);
    end;

  begin
    if stopRequested=nil then shouldStop:=@constantFalse else shouldStop:=stopRequested;
    kernel:=getSmoothingKernel(relativeBlurSigma/100*diagonal);
    output.create(dim.width,dim.height);
    for y:=0 to dim.height-1 do if not shouldStop() then
    for x:=0 to dim.width-1 do begin
      colSum:=getPixel(x,y)*kernel[0];
      wgtSum:=              kernel[0];
      for k:=0 to 1 do begin
        ix:=x;
        iy:=y;
        pos[cc_red  ]:=x;
        pos[cc_green]:=y;
        dir:=dirMap[x,y]*(k*2-1);
        step;
        for i:=1 to length(kernel)-1 do if (ix>=0) and (ix<dim.width) and (iy>=0) and (iy<dim.height) then begin
          colSum:=colSum+data[ix+iy*dim.width]*kernel[i];
          wgtSum:=wgtSum+                      kernel[i];
          step;
        end else break;
      end;
      output[x,y]:=colSum*(1/wgtSum);
    end;
    copyFromPixMap(output);
    output.destroy;
  end;

FUNCTION cartNormalCol(CONST c:T_rgbFloatColor):T_rgbFloatColor;
  begin
    result:=c*(1/sqrt(1E-6+c[cc_red]*c[cc_red]+c[cc_green]*c[cc_green]+c[cc_blue]*c[cc_blue]));
  end;

PROCEDURE T_rawImage.radialBlur(CONST relativeBlurSigma,relativeCenterX,relativeCenterY:double; CONST stopRequested:F_stopRequested=nil);
  VAR dirMap:T_rawImage;
      x,y:longint;
  begin
    dirMap.create(dim.width,dim.height);
    for y:=0 to dim.height-1 do for x:=0 to dim.width-1 do
      dirMap[x,y]:=cartNormalCol(rgbColor(x/dim.width-0.5-relativeCenterX,
                                          y/dim.height-0.5-relativeCenterY,
                                          0));
    lagrangeDiffusion(dirMap,relativeBlurSigma,false,stopRequested);
    dirMap.destroy;
  end;

PROCEDURE T_rawImage.rotationalBlur(CONST relativeBlurSigma,relativeCenterX,relativeCenterY:double; CONST stopRequested:F_stopRequested=nil);
  VAR dirMap:T_rawImage;
      x,y:longint;
  begin
    dirMap.create(dim.width,dim.height);
    for y:=0 to dim.height-1 do for x:=0 to dim.width-1 do
      dirMap[x,y]:=cartNormalCol(rgbColor(y/dim.height-0.5-relativeCenterY,
                                         -x/dim.width+0.5+relativeCenterX,
                                          0));
    lagrangeDiffusion(dirMap,relativeBlurSigma,false,stopRequested);
    dirMap.destroy;
  end;

PROCEDURE T_rawImage.shine;
  VAR temp:T_rawImage;
      pt:P_floatColor;
      co,ct:T_rgbFloatColor;
      fak:double;
      x,y,ix,iy,step:longint;
      anyOverbright:boolean;
  begin
    temp.create(dim.width,dim.height);
    pt:=temp.data;
    step:=1;
    repeat
      anyOverbright:=false;
      for x:=0 to dim.width*dim.height-1 do begin
        co:=data[x];
        ct:=co;
        fak:=max(1,(co[cc_red]+co[cc_green]+co[cc_blue])*(1/3));
        co:=co*(1/fak);
        data[x]:=co;
        pt[x]:=ct-co;
        anyOverbright:=anyOverbright or (fak>1.1);
      end;
      for y:=0 to dim.height-1 do
      for x:=0 to dim.width-1 do begin
        co:=pt[x+y*dim.width];
        if co<>BLACK then begin
          co:=co*(1/(2+4*step));
          for iy:=max(0,y-step) to min(dim.height-1,y+step) do data[x+iy*dim.width]:=data[x+iy*dim.width]+co;
          for ix:=max(0,x-step) to min(dim.width-1,x+step) do data[ix+y*dim.width]:=data[ix+y*dim.width]+co;
        end;
      end;
      inc(step,step);
    until (step>diagonal*0.2) or not(anyOverbright);
    temp.destroy;
  end;

PROCEDURE T_rawImage.sharpen(CONST relativeSigma,factor:double; CONST stopRequested:F_stopRequested=nil);
  VAR blurred:T_rawImage;
      x,y:longint;
  begin
    blurred.create(self);
    blurred.blur(relativeSigma,relativeSigma,stopRequested);
    for y:=0 to dim.height-1 do for x:=0 to dim.width-1 do pixel[x,y]:= blurred[x,y]+(pixel[x,y]-blurred[x,y])*(1+factor);
    blurred.destroy;
  end;

PROCEDURE T_rawImage.prewittEdges;
  VAR x,y,i:longint;

  begin
    //first change to greyscale:
    for i:=0 to dim.width*dim.height-1 do data[i]:=subjectiveGrey(data[i]);
    //x-convolution to green channel
    for y:=0 to dim.height-1 do begin
      data[y*dim.width][cc_green]:=0;
      for x:=1 to dim.width-2 do data[x+y*dim.width][cc_green]:=data[x+y*dim.width+1][cc_red]
                                                         -data[x+y*dim.width-1][cc_red];
      data[dim.width-1+y*dim.width][cc_green]:=0;
    end;
    //Re-convolition to blue channel
    for x:=0 to dim.width-1 do data[x][cc_blue]:=(data[x][cc_green]+data[x+dim.width][cc_green])*0.5;
    for y:=1 to dim.height-2 do for x:=0 to dim.width-1 do
      data[x+y*dim.width][cc_blue]:=data[x+y*dim.width-dim.width][cc_green]*0.2
                                  +data[x+y*dim.width     ][cc_green]*0.6
                                  +data[x+y*dim.width+dim.width][cc_green]*0.2;
    for i:=dim.width*dim.height-dim.width to dim.width*dim.height-1 do data[i][cc_blue]:=(data[i-dim.width][cc_green]+data[i][cc_green])*0.5;
    //y-convolution to green channel
                          for x:=0 to dim.width-1 do data[x       ][cc_green]:=0;
    for y:=1 to dim.height-2 do for x:=0 to dim.width-1 do data[x+y*dim.width][cc_green]:=data[x+y*dim.width+dim.width][cc_red]-data[x+y*dim.width-dim.width][cc_red];
        for i:=dim.width*dim.height-dim.width to dim.width*dim.height-1 do data[i       ][cc_green]:=0;
    //Re-convolution to red channel
    for y:=0 to dim.height-1 do begin
      data[y*dim.width][cc_red]:=(data[y*dim.width][cc_green]+data[y*dim.width+1][cc_green])*0.5;
      for x:=1 to dim.width-2 do
        data[x+y*dim.width][cc_red]:=data[x+y*dim.width-1][cc_green]*0.2
                                   +data[x+y*dim.width  ][cc_green]*0.6
                                   +data[x+y*dim.width+1][cc_green]*0.2;
      i:=dim.width-1+y*dim.width;
      data[i][cc_red]:=(data[i-1][cc_green]+data[i][cc_green])*0.5;
    end;
    for i:=0 to dim.width*dim.height-1 do data[i]:=WHITE*sqrt(sqr(data[i][cc_red])+sqr(data[i][cc_blue]));
  end;

{local} FUNCTION pot2(CONST c:T_rgbFloatColor):T_rgbFloatColor;
  VAR i:T_colorChannel;
  begin
    for i in RGB_CHANNELS do result[i]:=sqr(c[i]);
  end;

{local} FUNCTION pot3(CONST c:T_rgbFloatColor):T_rgbFloatColor;
  VAR i:T_colorChannel;
  begin
    for i in RGB_CHANNELS do result[i]:=sqr(c[i])*c[i];
  end;

PROCEDURE T_rawImage.variance(CONST relativeSigma:double);
  VAR m2:T_rawImage;
      i:longint;
  begin
    m2.create(dim.width,dim.height);
    for i:=0 to pixelCount-1 do m2.data[i]:=pot2(data[i]);
       blur(relativeSigma,relativeSigma);
    m2.blur(relativeSigma,relativeSigma);
    for i:=0 to pixelCount-1 do data[i]:=m2.data[i]-pot2(data[i]);
    m2.destroy;
  end;

PROCEDURE T_rawImage.medianFilter(CONST relativeSigma:double);
  TYPE T_samplingWeight=record dx,dy,w:longint; end;

  VAR tempCopy:T_rawImage;
      x,y:longint;
      sampling:array of T_samplingWeight;
      s:T_samplingWeight;
      hist:array[cc_red..cc_blue] of array[0..255] of longint;
      byteCol:T_rgbColor;

  PROCEDURE clearHistogram;
    VAR channel:T_colorChannel;
        k:longint;
    begin
      for channel in RGB_CHANNELS do for k:=0 to 255 do hist[channel,k]:=0;
    end;

  FUNCTION histogramMedian:T_rgbColor;
    VAR channel:T_colorChannel;
        k:longint;
        count,medCount:longint;
    begin
      result:=WHITE;
      for channel in RGB_CHANNELS do begin
        count:=0;
        for k:=0 to 255 do count+=hist[channel,k];
        medCount:=count shr 1;
        count:=0;
        for k:=0 to 255 do begin
          count+=hist[channel,k];
          if count>=medCount then begin
            result[channel]:=k;
            break;
          end;
        end;
      end;
    end;

  PROCEDURE initSampling;
    VAR radius:double;
        ix,iy:longint;
        weight:longint;
    begin
      radius:=relativeSigma/100*diagonal+0.5;
      for iy:=-floor(radius) to ceil(radius) do
      for ix:=-floor(radius) to ceil(radius) do begin
        weight:=round(4*min(1,radius-sqrt(ix*ix+iy*iy)));
        if weight>0 then begin
          setLength(sampling,length(sampling)+1);
          with sampling[length(sampling)-1] do begin
            dx:=ix;
            dy:=iy;
            w :=weight;
          end;
        end;
      end;
    end;

  begin
    tempCopy.create(self);
    setLength(sampling,0);
    initSampling;
    for y:=0 to dim.height-1 do for x:=0 to dim.width-1 do begin
      clearHistogram;
      for s in sampling do with s do if (x+dx>=0) and (x+dx<dim.width) and (y+dy>=0) and (y+dy<dim.height) then begin
        byteCol:=tempCopy[x+dx,y+dy];
        hist[cc_red  ,byteCol[cc_red  ]]+=w;
        hist[cc_green,byteCol[cc_green]]+=w;
        hist[cc_blue ,byteCol[cc_blue ]]+=w;
      end;
      pixel[x,y]:=histogramMedian;
    end;
    setLength(sampling,0);
    tempCopy.destroy;
  end;

PROCEDURE T_rawImage.modalFilter(CONST relativeSigma:double);
  VAR output:T_rawImage;
      x,y:longint;
      kernel:T_arrayOfDouble;
      hist:T_compoundHistogram;

  PROCEDURE scan; inline;
    VAR dx,dy:longint;
        wy:double;
    begin
      hist.clear;
      for dy:=max(-y,1-length(kernel)) to min(dim.height-y,length(kernel))-1 do begin
        wy:=kernel[abs(dy)];
        for dx:=max(-x,1-length(kernel)) to min(dim.width-x,length(kernel))-1 do
          hist.putSampleSmooth(pixel[x+dx,y+dy],kernel[abs(dx)]*wy);
      end;
    end;
  begin
    hist.create;
    output.create(dim.width,dim.height);
    kernel:=getSmoothingKernel(relativeSigma/100*diagonal);
    for y:=0 to dim.height-1 do for x:=0 to dim.width-1 do begin
      scan;
      output[x,y]:=rgbColor(hist.R.mode,hist.G.mode,hist.B.mode);
    end;
    copyFromPixMap(output);
    hist.destroy;
    output.destroy;
  end;

PROCEDURE T_rawImage.sketch(CONST cover,relativeDirMapSigma,density,tolerance:double; CONST stopRequested:F_stopRequested=nil);
  VAR halfwidth:double;
      fixedDensity:double;
  PROCEDURE niceLine(CONST x0,y0,x1,y1:double; CONST color:T_rgbFloatColor; CONST alpha:double);
    VAR ix,iy:longint;
        slope:double;

    FUNCTION cover(CONST z0:double; CONST z:longint):double;
      begin
        result:=halfwidth-abs(z-z0);
        if result<0 then result:=0 else if result>1 then result:=1;
      end;

    PROCEDURE xStep; inline;
      VAR y,a:double;
          k:longint;
      begin
        y:=y0+slope*(ix-x0);
        for k:=floor(y-halfwidth) to ceil(y+halfwidth) do if (k>=0) and (k<dim.height) then begin
          a:=alpha*cover(y,k);
          if a>0 then data[ix+k*dim.width]:=data[ix+k*dim.width]*(1-a)+color*a;
        end;
      end;

    PROCEDURE yStep; inline;
      VAR x,a:double;
          k:longint;
      begin
        x:=x0+slope*(iy-y0);
        for k:=floor(x-halfwidth) to ceil(x+halfwidth) do if (k>=0) and (k<dim.width) then begin
          a:=alpha*cover(x,k);
          if a>0 then data[k+iy*dim.width]:=data[k+iy*dim.width]*(1-a)+color*a;
        end;
      end;

    begin
      if abs(x1-x0)>abs(y1-y0) then begin
        slope:=(y1-y0)/(x1-x0);
        if x1>=x0
        then for ix:=max(round(x0),0) to min(dim.width-1,round(x1)) do xStep
        else for ix:=max(round(x1),0) to min(dim.width-1,round(x0)) do xStep;
      end else if abs(y1-y0)>0 then begin
        slope:=(x1-x0)/(y1-y0);
        if y1>=y0
        then for iy:=max(round(y0),0) to min(dim.height-1,round(y1)) do yStep
        else for iy:=max(round(y1),0) to min(dim.height-1,round(y0)) do yStep;
      end else begin
        ix:=round((x0+x1)/2);
        iy:=round((y0+y1)/2);
        if (ix>=0) and (ix<dim.width) and (iy>=0) and (iy<dim.height) then
        data[ix+iy*dim.width]:=
        data[ix+iy*dim.width]*(1-alpha)+color*alpha;
      end;
    end;

  FUNCTION lev(CONST i,j:longint):longint;
    VAR k:longint;
    begin
      k:=i or j;
      if k=0 then exit(12)
      else begin
        result:=0;
        while not(odd(k)) do begin
          inc(result);
          k:=k shr 1;
        end;
      end;
    end;

  VAR temp,grad:T_rawImage;
      x,y,i,imax,k,l:longint;
      lineX,lineY:array[0..1] of double;
      lineColor:T_rgbFloatColor;
      alpha:single;
      dir:T_rgbFloatColor;

  FUNCTION isTolerable(CONST fx,fy:double):boolean; inline;
    VAR ix,iy:longint;
    begin
      ix:=round(fx); if (ix<0) or (ix>=dim.width) then exit(false);
      iy:=round(fy); if (iy<0) or (iy>=dim.height) then exit(false);
      result:=colDiff(temp[ix,iy],lineColor)<=tolerance;
    end;

  VAR shouldStop:F_stopRequested;

  begin
    if stopRequested=nil then shouldStop:=@constantFalse else shouldStop:=stopRequested;
    halfwidth:=diagonal/1500+0.25;
    grad:=directionMap(relativeDirMapSigma);
    temp.create(self);
    for x:=0 to dim.width*dim.height-1 do data[x]:=WHITE;
    alpha:=cover;
    fixedDensity:=density/(dim.width*dim.height)*1E6;
    if fixedDensity>1 then alpha:=exp(fixedDensity*ln(cover));
    if alpha>1 then alpha:=1;
    for l:=0 to 12 do for y:=0 to dim.height-1 do if not shouldStop() then for x:=0 to dim.width-1 do if (lev(x,y)=l) and (random<fixedDensity) then begin
      lineColor:=temp[x,y]+rgbColor(random-0.5,random-0.5,random-0.5)*0.05;
      dir:=grad[x,y];
      for k:=0 to 1 do begin
        i:=0;
        imax:=round(random*diagonal*0.05);
        while (i<imax) and isTolerable(x+i*dir[cc_red],y+i*dir[cc_green]) do inc(i);
        lineX[k]:=x+i*dir[cc_red];
        lineY[k]:=y+i*dir[cc_green];
        dir:=dir*(-1);
      end;
      niceLine(lineX[0],lineY[0],lineX[1],lineY[1],lineColor,(alpha));
    end;
    temp.destroy;
    grad.destroy;
  end;

PROCEDURE T_rawImage.myFilter(CONST thresholdDistParam,param:double; CONST stopRequested:F_stopRequested=nil);
  FUNCTION combine(CONST m1,m2,m3:T_rgbFloatColor):T_rgbFloatColor;
{skew=(mean-median)/[standard deviation]
skew=(M[1]-median)/s
skew=(M[3]-3M[1]s²-M[1]³)/s³
median=M[1]-s*skew
      =M[1]-s*(M[3]-3M[1]s²-M[1]³)/s³
      =M[1]-  (M[3]-3M[1]s²-M[1]³)/s²
      =M[1]-  (M[3]-3M[1]s²-M[1]³)/s²
s=sqrt(M[2]-sqr(M[1]))
 }
    VAR sigma,weight:double;
        i:T_colorChannel;
    begin
      for i in RGB_CHANNELS do begin
        sigma:=m2[i]-m1[i]*m1[i];
        if sigma<1E-8 then result[i]:=m1[i]
        else begin
          sigma:=sqrt(sigma);
          weight:=param*sigma*arctan((m3[i]-m1[i]*m1[i]*m1[i])/(sigma*sigma*sigma)-3*m1[i]/sigma);
          result[i]:=m1[i]-weight;
        end;
      end;
    end;

  VAR m2,m3:T_rawImage;
      i:longint;
      shouldStop:F_stopRequested;
  begin
    if stopRequested=nil then shouldStop:=@constantFalse else shouldStop:=stopRequested;
    m2.create(dim.width,dim.height);
    for i:=0 to dim.width*dim.height-1 do m2.data[i]:=pot2(data[i]);
    m3.create(dim.width,dim.height);
    for i:=0 to dim.width*dim.height-1 do m3.data[i]:=pot3(data[i]);
    blur(thresholdDistParam,thresholdDistParam,shouldStop);
    m2.blur(thresholdDistParam,thresholdDistParam,shouldStop);
    m3.blur(thresholdDistParam,thresholdDistParam,shouldStop);
    if not shouldStop() then for i:=0 to dim.width*dim.height-1 do data[i]:=combine(data[i],m2.data[i],m3.data[i]);
    m2.destroy;
    m3.destroy;
  end;

PROCEDURE T_rawImage.drip(CONST diffusiveness,range:double);
  CONST dt=0.5;
  VAR stepCount:longint;
      delta:T_rawImage;
  PROCEDURE applyDelta;
    VAR i:longint;
    begin
      for i:=0 to pixelCount-1 do data[i]:=data[i]+delta.data[i]*dt;
    end;

  PROCEDURE computeDelta;
    VAR x,y:longint;
        v:double;
        flux:T_rgbFloatColor;
    begin
      delta.clearWithColor(BLACK);
      for y:=0 to dim.height-1 do for x:=0 to dim.width-1 do begin
        v:=T_hsvColor(pixel[x,y])[hc_saturation];
        if v>1 then v:=1 else if v<0 then v:=0;
        flux:=pixel[x,y]*v;
                         delta[x,y  ]:=delta[x,y  ]-flux;
        if y<dim.height-1 then delta[x,y+1]:=delta[x,y+1]+flux;
      end;
      if diffusiveness>0 then begin;
        for y:=0 to dim.height-1 do for x:=0 to dim.width-2 do begin
          flux:=(pixel[x,y]-pixel[x+1,y])*diffusiveness;
          delta[x  ,y]:=delta[x  ,y]-flux;
          delta[x+1,y]:=delta[x+1,y]+flux;
        end;
        for y:=0 to dim.height-2 do for x:=0 to dim.width-1 do begin
          flux:=(pixel[x,y]-pixel[x,y+1])*diffusiveness;
          delta[x,y  ]:=delta[x,y  ]-flux;
          delta[x,y+1]:=delta[x,y+1]+flux;
        end;
      end;
    end;

  VAR i:longint;
  begin
    stepCount:=round(range*diagonal/dt);
    delta.create(dim.width,dim.height);
    for i:=0 to stepCount-1 do begin
      computeDelta;
      applyDelta;
    end;
    delta.destroy;
  end;

FUNCTION T_rawImage.rgbaSplit(CONST transparentColor:T_rgbFloatColor):T_rawImage;
  PROCEDURE rgbToRGBA(CONST c00,c01,c02,
                            c10,c11,c12,
                            c20,c21,c22,
                            transparentColor:T_rgbFloatColor; OUT rgb:T_rgbFloatColor; OUT alpha:single);
    VAR aMax,a:single;
    begin
      aMax :=abs(c00[cc_red]-transparentColor[cc_red])+abs(c00[cc_green]-transparentColor[cc_green])+abs(c00[cc_blue]-transparentColor[cc_blue]);
      a    :=abs(c01[cc_red]-transparentColor[cc_red])+abs(c01[cc_green]-transparentColor[cc_green])+abs(c01[cc_blue]-transparentColor[cc_blue]); if a    >aMax then aMax:=a;
      a    :=abs(c02[cc_red]-transparentColor[cc_red])+abs(c02[cc_green]-transparentColor[cc_green])+abs(c02[cc_blue]-transparentColor[cc_blue]); if a    >aMax then aMax:=a;
      a    :=abs(c10[cc_red]-transparentColor[cc_red])+abs(c10[cc_green]-transparentColor[cc_green])+abs(c10[cc_blue]-transparentColor[cc_blue]); if a    >aMax then aMax:=a;
      alpha:=abs(c11[cc_red]-transparentColor[cc_red])+abs(c11[cc_green]-transparentColor[cc_green])+abs(c11[cc_blue]-transparentColor[cc_blue]); if alpha>aMax then aMax:=alpha;
      a    :=abs(c12[cc_red]-transparentColor[cc_red])+abs(c12[cc_green]-transparentColor[cc_green])+abs(c12[cc_blue]-transparentColor[cc_blue]); if a    >aMax then aMax:=a;
      a    :=abs(c20[cc_red]-transparentColor[cc_red])+abs(c20[cc_green]-transparentColor[cc_green])+abs(c20[cc_blue]-transparentColor[cc_blue]); if a    >aMax then aMax:=a;
      a    :=abs(c21[cc_red]-transparentColor[cc_red])+abs(c21[cc_green]-transparentColor[cc_green])+abs(c21[cc_blue]-transparentColor[cc_blue]); if a    >aMax then aMax:=a;
      a    :=abs(c22[cc_red]-transparentColor[cc_red])+abs(c22[cc_green]-transparentColor[cc_green])+abs(c22[cc_blue]-transparentColor[cc_blue]); if a    >aMax then aMax:=a;
      if aMax>1E-3 then begin
        alpha:=max(0,min(1,alpha/aMax));
        rgb:=(c11-transparentColor*(1-alpha))*(1/alpha);
      end else begin
        rgb:=BLACK;
        alpha:=0;
      end;
    end;
  VAR x,y,xm,ym:longint;
      rgb:T_rgbFloatColor;
      alpha:single;
      source:T_rawImage;
  begin
    result.create(dim.width,dim.height);
    source.create(self);
    xm:=dim.width-1;
    ym:=dim.height-1;
    for y:=0 to ym do for x:=0 to xm do begin
      rgbToRGBA(source[max( 0,x-1),max( 0,y-1)],
                source[       x   ,max( 0,y-1)],
                source[min(xm,x+1),max( 0,y-1)],
                source[max( 0,x-1),       y   ],
                source[       x   ,       y   ],
                source[min(xm,x+1),       y   ],
                source[max( 0,x-1),min(ym,y+1)],
                source[       x   ,min(ym,y+1)],
                source[min(xm,x+1),min(ym,y+1)],
                transparentColor,rgb,alpha);
      pixel[x,y]:=rgb;
      result[x,y]:=WHITE*alpha;
    end;
  end;

PROCEDURE T_rawImage.halftone(CONST scale:single; CONST param:longint);
  VAR xRes,yRes:longint;
      temp:T_rawImage;

  FUNCTION avgSqrRad(x0,y0,rad:single):T_rgbFloatColor; inline;
    VAR x,y,k:longint;
    begin
      result:=BLACK;
      k:=0;
      for y:=max(0,floor(y0-rad)) to min(yRes-1,ceil(y0+rad)) do
      for x:=max(0,floor(x0-rad)) to min(xRes-1,ceil(x0+rad)) do
      if sqr(x-x0)+sqr(y-y0)<sqr(rad) then begin
        result:=result+pixel[x,y];
        inc(k);
      end;
      if k>0 then begin
        result:=result*(1/k);
        if result[cc_red  ]<0 then result[cc_red  ]:=0 else result[cc_red  ]:=sqr(rad*2)*result[cc_red  ]/pi;
        if result[cc_green]<0 then result[cc_green]:=0 else result[cc_green]:=sqr(rad*2)*result[cc_green]/pi;
        if result[cc_blue ]<0 then result[cc_blue ]:=0 else result[cc_blue ]:=sqr(rad*2)*result[cc_blue ]/pi;
      end;
    end;

  FUNCTION avgCover(x,y,sqrRad:single):single; inline;
    VAR k,i,j:longint;
    begin
      k:=0;
      if sqr(x-0.375)+sqr(y-0.375)<sqrRad then inc(k);
      if sqr(x-0.375)+sqr(y+0.375)<sqrRad then inc(k);
      if sqr(x+0.375)+sqr(y-0.375)<sqrRad then inc(k);
      if sqr(x+0.375)+sqr(y+0.375)<sqrRad then inc(k);
      if k=0 then result:=0 else if k=4 then result:=1
      else begin
        for i:=0 to 3 do for j:=0 to 3 do
          if sqr(x-0.375+i*0.25)+
             sqr(y-0.375+j*0.25)<sqrRad then inc(k);
        result:=(k-4)/16;
      end;
    end;

  PROCEDURE paintCircle(x0,y0:single; rad:T_rgbFloatColor);
    VAR cov,col:T_rgbFloatColor;
        x,y:longint;
        mrad:single;
    begin
      mrad:=sqrt(max(rad[cc_red],max(rad[cc_green],rad[cc_blue])));
      for y:=max(0,floor(y0-mrad)) to min(yRes-1,ceil(y0+mrad)) do
      for x:=max(0,floor(x0-mrad)) to min(xRes-1,ceil(x0+mrad)) do begin
        cov[cc_red  ]:=avgCover(x-x0,y-y0,rad[cc_red  ]);
        cov[cc_green]:=avgCover(x-x0,y-y0,rad[cc_green]);
        cov[cc_blue ]:=avgCover(x-x0,y-y0,rad[cc_blue ]);
        col:=pixel[x,y];
        col[cc_red  ]:=max(col[cc_red  ],cov[cc_red  ]);
        col[cc_green]:=max(col[cc_green],cov[cc_green]);
        col[cc_blue ]:=max(col[cc_blue ],cov[cc_blue ]);
        pixel[x,y]:=col;
      end;
    end;

  PROCEDURE paintCircle(x0,y0,rad:single; channel:T_colorChannel);
    VAR cov:single;
        col:T_rgbFloatColor;
        x,y:longint;
    begin
      for y:=max(0,floor(y0-sqrt(rad))) to min(yRes-1,ceil(y0+sqrt(rad))) do
      for x:=max(0,floor(x0-sqrt(rad))) to min(xRes-1,ceil(x0+sqrt(rad))) do begin
        cov:=avgCover(x-x0,y-y0,rad);
        col:=pixel[x,y];
        col[channel]:=max(col[channel],cov);
        pixel[x,y]:=col;
      end;
    end;

  VAR x,y:longint;
      sx:single;
      pt:P_floatColor;
  begin
    xRes:=dim.width;
    yRes:=dim.height;
    pt:=rawData;
    if param and 1=1 then for x:=0 to dim.width*dim.height-1 do pt[x]:=WHITE-pt[x];
    //analyze:
    if param and 4=0 then begin
      temp.create(ceil(xRes/scale+2),ceil(yRes/scale+2));
      if param and 2=0 then begin
        for y:=0 to temp.dim.height-1 do for x:=0 to temp.dim.width-1 do temp[x,y]:=avgSqrRad(x*scale,y*scale,0.5*scale);
      end else begin
        for y:=0 to temp.dim.height-1 do for x:=0 to temp.dim.width-1 do temp[x,y]:=rgbColor(
          avgSqrRad( x     *scale, y     *scale,0.5*scale)[cc_red  ],
          avgSqrRad( x     *scale,(y+0.5)*scale,0.5*scale)[cc_green],
          avgSqrRad((x+0.5)*scale, y     *scale,0.5*scale)[cc_blue ]);
      end;
    end else begin
      temp.create(ceil(xRes/scale+2),ceil(yRes/(scale*0.86602540378444)+2));
      if param and 2=0 then begin
        for y:=0 to temp.dim.height-1 do begin
          if odd(y) then sx:=0.5*scale else sx:=0;
          for x:=0 to temp.dim.width-1 do temp[x,y]:=avgSqrRad(sx+x*scale,y*scale*0.86602540378444,0.5*scale);
        end;
      end else begin
        for y:=0 to temp.dim.height-1 do begin
          if odd(y) then sx:=0.5*scale else sx:=0;
          for x:=0 to temp.dim.width-1 do temp[x,y]:=rgbColor(
            avgSqrRad(sx+ x      *scale, y     *scale*0.86602540378444,0.5*scale)[cc_red  ],
            avgSqrRad(sx+(x+0.25)*scale,(y+0.5)*scale*0.86602540378444,0.5*scale)[cc_green],
            avgSqrRad(sx+(x+0.5 )*scale, y     *scale*0.86602540378444,0.5*scale)[cc_blue ]);
        end;
      end;
    end;
    //:analyze
    //draw:
    pt:=rawData;
    for x:=0 to xRes*yRes-1 do pt[x]:=BLACK;
    if param and 4=0 then begin
      if param and 2=0 then begin
        for y:=0 to temp.dim.height-1 do for x:=0 to temp.dim.width-1 do paintCircle(x*scale,y*scale,temp[x,y]);
      end else begin
        for y:=0 to temp.dim.height-1 do for x:=0 to temp.dim.width-1 do begin
          paintCircle( x     *scale, y     *scale,temp[x,y][cc_red  ],cc_red  );
          paintCircle( x     *scale,(y+0.5)*scale,temp[x,y][cc_green],cc_green);
          paintCircle((x+0.5)*scale, y     *scale,temp[x,y][cc_blue ],cc_blue );
        end;
      end;
    end else begin
      if param and 2=0 then begin
        for y:=0 to temp.dim.height-1 do begin
          if odd(y) then sx:=0.5*scale else sx:=0;
          for x:=0 to temp.dim.width-1 do paintCircle(sx+x*scale,y*scale*0.86602540378444,temp[x,y]);
        end;
      end else begin
        for y:=0 to temp.dim.height-1 do for x:=0 to temp.dim.width-1 do begin
          if odd(y) then sx:=0.5*scale else sx:=0;
          paintCircle(sx+(x-0.5 )*scale, y     *scale*0.86602540378444,temp[x,y][cc_red  ],cc_red  );
          paintCircle(sx+(x-0.25)*scale,(y+0.5)*scale*0.86602540378444,temp[x,y][cc_green],cc_green);
          paintCircle(sx+(x     )*scale, y     *scale*0.86602540378444,temp[x,y][cc_blue ],cc_blue );
        end;
      end;
    end;
    temp.destroy;
    if param and 1=1 then for x:=0 to xRes*yRes-1 do pt[x]:=WHITE-pt[x];
  end;

PROCEDURE T_rawImage.rotate(CONST angleInDegrees:double; CONST highQuality:boolean);
  VAR A:array[0..1] of double;
      temp:T_rawImage;
      x,y:longint;
      cx,cy:double;
      i,j:double;

  FUNCTION hqPixel(CONST ix,iy:double):T_rgbFloatColor;
    VAR k:longint;
        points:T_pointList;
    begin
      if highQuality then begin
        points.clear;
        for k:=0 to 31 do points.add(A[0]*(ix+darts_delta[k,0])+A[1]*(iy+darts_delta[k,1])+cx,
                                     A[0]*(iy+darts_delta[k,1])-A[1]*(ix+darts_delta[k,0])+cy);
        result:=temp.subPixelAverage(points);
      end else result:=temp.simpleSubPixel(A[0]*ix+A[1]*iy+cx,
                                           A[0]*iy-A[1]*ix+cy);
    end;

  begin
    A[0]:=cos(angleInDegrees/180*pi);
    A[1]:=sin(angleInDegrees/180*pi);
    temp.create(self);
    cx:=(dim.width-1)/2;
    cy:=(dim.height-1)/2;
    for y:=0 to dim.height-1 do
    for x:=0 to dim.width-1 do begin
      i:=x-cx;
      j:=y-cy;
      pixel[x,y]:=hqPixel(i,j);
    end;
    temp.destroy;
  end;

PROCEDURE T_rawImage.copyFromImageWithOffset(VAR image:T_rawImage; CONST xOff,yOff:longint);
  VAR sx,sy,tx,ty:longint;
  begin
    for sy:=0 to image.dimensions.height-1 do begin
      ty:=sy+yOff;
      if (ty>=0) and (ty<dimensions.height) then
      for sx:=0 to image.dimensions.width-1 do begin
        tx:=sx+xOff;
        if (tx>=0) and (tx<dimensions.width) then pixel[tx,ty]:=image[sx,sy];
      end;
    end;
  end;

FUNCTION T_rawImage.simpleSubPixel(CONST x,y:double):T_rgbFloatColor;
  VAR kx,ky:longint;
  begin
    kx:=round(x); if kx<0 then kx:=0 else if kx>=dim.width then kx:=dim.width-1;
    ky:=round(y); if ky<0 then ky:=0 else if ky>=dim.height then ky:=dim.height-1;
    result:=data[kx+ky*dim.width];
  end;

FUNCTION T_rawImage.subPixelAverage(CONST points:T_pointList):T_rgbFloatColor;
  VAR kx,ky:array[0..2] of longint;
      i:longint;
      relX,relY:double;
      col:array[0..2] of T_rgbFloatColor;

  FUNCTION between(CONST c0,c1,c2:T_rgbFloatColor; CONST tau:double):T_rgbFloatColor; inline;
    VAR w0,w1,w2:double;
    begin
      w0:=-1.6875+tau*( 13.5+tau*(-27+tau*( 20- 5*tau)));
      w1:= 5.375 +tau*(-28  +tau*( 54+tau*(-40+10*tau)));
      w2:=-2.6875+tau*( 14.5+tau*(-27+tau*( 20- 5*tau)));
      result[cc_red]  :=c0[cc_red  ]*w0+c1[cc_red  ]*w1+c2[cc_red  ]*w2;
      result[cc_green]:=c0[cc_green]*w0+c1[cc_green]*w1+c2[cc_green]*w2;
      result[cc_blue] :=c0[cc_blue ]*w0+c1[cc_blue ]*w1+c2[cc_blue ]*w2;
    end;

  VAR pointIndex:longint;
      lastKx0:longint=maxLongint;
      lastKy0:longint=maxLongint;
  begin
    result:=BLACK;
    for pointIndex:=0 to points.fill-1 do with points.points[pointIndex] do begin
      kx[0]:=round(x)-1; relX:=x-kx[0];
      ky[0]:=round(y)-1; relY:=y-ky[0];
      if (kx[0]<>lastKx0) or (ky[0]<>lastKy0) then begin
        lastKx0:=kx[0]; lastKy0:=ky[0];
        for i:=1 to 2 do kx[i]:=kx[0]+i;
        for i:=1 to 2 do ky[i]:=ky[0]+i;
        for i:=0 to 2 do if kx[i]<0 then kx[i]:=0 else if kx[i]>=dim.width  then kx[i]:=dim.width -1;
        for i:=0 to 2 do if ky[i]<0 then ky[i]:=0 else if ky[i]>=dim.height then ky[i]:=dim.height-1;
      end else begin
        if kx[0]<0 then kx[0]:=0 else if kx[0]>=dim.width  then kx[0]:=dim.width -1;
        if ky[0]<0 then ky[0]:=0 else if ky[0]>=dim.height then ky[0]:=dim.height-1;
      end;
      for i:=0 to 2 do
        col[i]:=between(data[kx[0]+ky[i]*dim.width],data[kx[1]+ky[i]*dim.width],data[kx[2]+ky[i]*dim.width],relX);
      result  +=between(col[0]                     ,col[1]                     ,col[2]                     ,relY);
    end;
    result*=1/points.fill;
  end;

FUNCTION T_rawImage.subPixelBoxAvg(CONST x0,x1,y0,y1:double):T_rgbFloatColor;
  FUNCTION integrate(CONST c0,c1,c2:T_rgbFloatColor; CONST tau,phi:double):T_rgbFloatColor; inline;
    VAR tau2,tau3,tau4,tau5,
        dTau,dTau2,dTau3,dTau4,dTau5,
        w0,w1,w2:double;
    begin
      tau2:=sqr(tau); tau3:=tau*tau2; tau4:=tau*tau3; tau5:=tau*tau4;
      dTau:=phi-tau;
      dTau2:=sqr(phi); dTau3:=phi*dTau2; dTau4:=phi*dTau3; dTau5:=phi*dTau4-tau5;
      dTau2-=tau2; dTau3-=tau3; dTau4-=tau4;
      w0:=-1.6875*dTau + 6.75*dTau2 -  9*dTau3 +  5*dTau4 - 1*dTau5;
      w1:=  5.375*dTau - 14  *dTau2 + 18*dTau3 - 10*dTau4 + 2*dTau5;
      w2:=-2.6875*dTau + 7.25*dTau2 -  9*dTau3 +  5*dTau4 - 1*dTau5;
      result[cc_red]  :=c0[cc_red  ]*w0+c1[cc_red  ]*w1+c2[cc_red  ]*w2;
      result[cc_green]:=c0[cc_green]*w0+c1[cc_green]*w1+c2[cc_green]*w2;
      result[cc_blue] :=c0[cc_blue ]*w0+c1[cc_blue ]*w1+c2[cc_blue ]*w2;
    end;

  VAR total:array[RGB_CHANNELS] of double=(0,0,0);
  PROCEDURE addToTotal(CONST rgb:T_rgbFloatColor); inline;
    begin
      total[cc_red  ]+=rgb[cc_red  ];
      total[cc_green]+=rgb[cc_green];
      total[cc_blue ]+=rgb[cc_blue ];
    end;

  VAR x,y,i:longint;
      subY0,subY1,subX0,subX1,y_tau,y_phi,x_tau,x_phi:double;
      fullY,fullX:boolean;
      kx,ky:array[0..2] of longint;
      col:array[0..2] of T_rgbFloatColor;
  begin
    for y:=round(y0) to round(y1) do begin
      subY0:=min(min(max(max(y-0.5,y0),-0.5),y1),dimensions.height-0.5);
      subY1:=min(min(max(max(y+0.5,y0),-0.5),y1),dimensions.height-0.5);
      ky[0]:=y-1;
      y_tau:=subY0-ky[0];
      y_phi:=subY1-ky[0];
      for i:=1 to 2 do ky[i]:=ky[0]+i;
      for i:=0 to 2 do if ky[i]<0 then ky[i]:=0 else if ky[i]>=dim.height then ky[i]:=dim.height-1;
      fullY:=(abs(y_tau-0.5)<1E-3) and (abs(y_phi-0.5)<1E-3);

      for x:=round(x0) to round(x1) do begin
        subX0:=min(min(max(max(x-0.5,x0),-0.5),x1),dimensions.width-0.5);
        subX1:=min(min(max(max(x+0.5,x0),-0.5),x1),dimensions.width-0.5);
        kx[0]:=x-1;
        x_tau:=subX0-kx[0];
        x_phi:=subX1-kx[0];
        for i:=1 to 2 do kx[i]:=kx[0]+i;
        for i:=0 to 2 do if kx[i]<0 then kx[i]:=0 else if kx[i]>=dim.width then kx[i]:=dim.width -1;
        fullX:=(abs(x_tau-0.5)<1E-3) and (abs(x_phi-0.5)<1E-3);

        if fullX and fullY then addToTotal(data[kx[1]+ky[1]*dim.width])
        else begin
          for i:=0 to 2 do col[i]:=integrate(data[kx[0]+ky[i]*dim.width],data[kx[1]+ky[i]*dim.width],data[kx[2]+ky[i]*dim.width],x_tau,x_phi);
          addToTotal(integrate(col[0],col[1],col[2],y_tau,y_phi));
        end;
      end;
    end;
    subY0:=1/(y1-y0)/(x1-x0);
    result[cc_red  ]:=total[cc_red  ]*subY0;
    result[cc_green]:=total[cc_green]*subY0;
    result[cc_blue ]:=total[cc_blue ]*subY0;
  end;

INITIALIZATION
  initCriticalSection(globalFileLock);
FINALIZATION
  doneCriticalSection(globalFileLock);

end.
