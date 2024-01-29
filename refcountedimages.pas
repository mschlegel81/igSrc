UNIT refCountedImages;

{$mode objfpc}{$H+}

INTERFACE
USES pixMaps,mypics,ExtCtrls;
TYPE
P_referenceCountedImage=^T_referenceCountedImage;

{ T_referenceCountedImage }

T_referenceCountedImage=object
  private
    id_:longword;
    refCount:longint;
    preview:TImage;
    DESTRUCTOR destroy;
  public
    image:T_rawImage;
    CONSTRUCTOR create(VAR original:T_rawImage);
    CONSTRUCTOR createFromFilename(CONST imageFilePath:string);
    FUNCTION previewImage:TImage;
    PROPERTY id:longword read id_;
end;

PROCEDURE disposeRCImage(VAR i:P_referenceCountedImage);
FUNCTION rereference(CONST i:P_referenceCountedImage):P_referenceCountedImage;
IMPLEMENTATION
USES sysutils;
VAR next_hash:longword=0;

PROCEDURE disposeRCImage(VAR i: P_referenceCountedImage);
  begin
    if i=nil then exit;
    if interlockedDecrement(i^.refCount)<=0 then
      dispose(i,destroy);
    i:=nil;
  end;

FUNCTION rereference(CONST i: P_referenceCountedImage): P_referenceCountedImage;
  begin
    if i=nil then exit(nil);
    interLockedIncrement(i^.refCount);
    result:=i;
  end;

DESTRUCTOR T_referenceCountedImage.destroy;
  begin
    if preview<>nil then FreeAndNil(preview);
    image.destroy;
  end;

CONSTRUCTOR T_referenceCountedImage.create(VAR original: T_rawImage);
  begin
    image.create(original);
    preview:=nil;
    id_:=interLockedIncrement(next_hash);
    refCount:=1;
  end;

CONSTRUCTOR T_referenceCountedImage.createFromFilename(CONST imageFilePath: string);
  begin
    image.create(imageFilePath);
    preview:=nil;
    id_:=interLockedIncrement(next_hash);
    refCount:=1;
  end;

FUNCTION T_referenceCountedImage.previewImage: TImage;
  begin
    if preview=nil then begin
      preview:=TImage.create(nil);
      image.copyToImage(preview);
    end;
    result:=preview;
  end;

end.

