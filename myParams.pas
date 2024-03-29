UNIT myParams;
INTERFACE
USES myColors,myGenerics,math,myStringUtil,sysutils;
CONST
  JPG_EXT='.JPG';
  JPEG_EXT='.JPEG';
  BMP_EXT='.BMP';
  PNG_EXT='.PNG';
  RAW_EXT='.VRAW';
  SUPPORTED_IMAGE_TYPES:array[0..4] of string=(JPG_EXT,JPEG_EXT,BMP_EXT,PNG_EXT,RAW_EXT);

  SIZE_LIMITABLE_EXTENSION=JPG_EXT;
TYPE
  T_parameterType=(pt_none,

                   pt_string,
                   pt_fileName,
                   pt_enum,

                   pt_integer,
                   pt_2integers,
                   pt_3integers,
                   pt_4integers,
                   pt_intOr2Ints,

                   pt_float,
                   pt_2floats,
                   pt_3floats,  pt_color,
                   pt_4floats,
                   pt_floatOr2Floats,

                   pt_jpgNameWithSize,
                   pt_1I1F,
                   pt_1I2F,
                   pt_1I3F,
                   pt_2I2F,

                   pt_resizeParameter);
  CONST I0_RELEVANT_PARAMETER_TYPES:set of T_parameterType=[pt_enum..pt_intOr2Ints,pt_1I1F..pt_1I3F,pt_resizeParameter];
        I1_RELEVANT_PARAMETER_TYPES:set of T_parameterType=[pt_2integers..pt_intOr2Ints,pt_jpgNameWithSize,pt_2I2F,pt_resizeParameter];
        I2_RELEVANT_PARAMETER_TYPES:set of T_parameterType=[pt_3integers,pt_4integers];
        I3_RELEVANT_PARAMETER_TYPES:set of T_parameterType=[pt_4integers];

        F0_RELEVANT_PARAMETER_TYPES:set of T_parameterType=[pt_float..pt_floatOr2Floats,pt_resizeParameter];
        F1_RELEVANT_PARAMETER_TYPES:set of T_parameterType=[pt_2floats..pt_floatOr2Floats,pt_1I1F..pt_1I3F];
        F2_RELEVANT_PARAMETER_TYPES:set of T_parameterType=[pt_3floats..pt_4floats,pt_1I2F..pt_1I3F,pt_2I2F];
        F3_RELEVANT_PARAMETER_TYPES:set of T_parameterType=[pt_4floats,pt_1I3F,pt_2I2F];
        REAL_VALUES_PARAMETER_TYPES:set of T_parameterType=[pt_float,pt_2floats,pt_3floats,pt_color,pt_4floats,pt_floatOr2Floats];
TYPE
  T_subParameterAssociation=(spa_filename,spa_i0,spa_i1,spa_i2,spa_i3,spa_f0,spa_f1,spa_f2,spa_f3);

  P_parameterDescription=^T_parameterDescription;

  T_parameterNameMode=(tsm_withoutParameterName,
                       tsm_withNiceParameterName,
                       tsm_forSerialization,
                       tsm_parameterNameOnly);

  P_parameterValue=^T_parameterValue;
  T_parameterValue=object
    private
      associatedParmeterDescription:P_parameterDescription;
      fileNameValue:string;
      intValue:array[0..3] of longint;
      floatValue:array[0..3] of double;
      flagValue:boolean;
      valid:boolean;
      PROCEDURE setFileName(CONST newValue:string);
      PROCEDURE setDefaults;
      PROCEDURE validate;
    public
      CONSTRUCTOR createCopy     (CONST other:P_parameterValue);
      CONSTRUCTOR createToParse  (CONST parameterDescription:P_parameterDescription; CONST stringToParse:string; CONST parameterNameMode:T_parameterNameMode=tsm_withoutParameterName);
      CONSTRUCTOR createFromValue(CONST parameterDescription:P_parameterDescription; CONST i0:longint; CONST i1:longint=0; CONST i2:longint=0; CONST i3:longint=0);
      CONSTRUCTOR createFromValue(CONST parameterDescription:P_parameterDescription; CONST f0:double; CONST f1:double=0; CONST f2:double=0; CONST f3:double=0);
      CONSTRUCTOR createFromValue(CONST parameterDescription:P_parameterDescription; CONST color:T_rgbFloatColor);
      CONSTRUCTOR createFromValue(CONST parameterDescription:P_parameterDescription; CONST txt:string; CONST sizeLimit:longint=-1);
      DESTRUCTOR destroy;
      FUNCTION canParse(CONST stringToParse:string; CONST parameterNameMode:T_parameterNameMode=tsm_withoutParameterName):boolean;
      PROPERTY isValid:boolean read valid;
      FUNCTION toString(CONST parameterNameMode:T_parameterNameMode=tsm_withoutParameterName):string;

      PROPERTY fileName:string read fileNameValue write setFileName;
      PROPERTY i0:longint read intValue[0];
      PROPERTY i1:longint read intValue[1];
      PROPERTY i2:longint read intValue[2];
      PROPERTY i3:longint read intValue[3];
      PROPERTY f0:double read floatValue[0];
      PROPERTY f1:double read floatValue[1];
      PROPERTY f2:double read floatValue[2];
      PROPERTY f3:double read floatValue[3];
      PROPERTY flag:boolean read flagValue;
      FUNCTION getNumericParameter(CONST index:byte):double;
      PROCEDURE setNumericParameter(CONST index:byte; CONST value:double);
      FUNCTION color:T_rgbFloatColor;
      FUNCTION strEq(CONST other:T_parameterValue):boolean;
      FUNCTION interpolate(CONST other:T_parameterValue; CONST step:double):T_parameterValue;

      PROCEDURE modifyI(CONST index:longint; CONST value:longint);
      PROCEDURE modifyF(CONST index:longint; CONST value:double);
      PROCEDURE copyFrom(CONST other:T_parameterValue; CONST forceParameterDescription:boolean=false);
      PROPERTY description:P_parameterDescription read associatedParmeterDescription;
  end;

  T_parameterDescription=object
    private
      name,defaultValue:string;
      typ :T_parameterType;
      minValue,maxValue:double;
      enumValues: T_arrayOfString;
      children:array of record
        association:T_subParameterAssociation;
        description:P_parameterDescription;
      end;
    public
    CONSTRUCTOR create(CONST name_: string;
                       CONST typ_: T_parameterType;
                       CONST minValue_: double= -infinity;
                       CONST maxValue_: double=  infinity);
    DESTRUCTOR destroy;
    FUNCTION shortName:string;
    FUNCTION setEnumValues(CONST txt:array of string):P_parameterDescription;
    FUNCTION addRGBChildParameters:P_parameterDescription;
    FUNCTION addHSVChildParameters:P_parameterDescription;
    FUNCTION addChildParameterDescription(
                       CONST association_:T_subParameterAssociation;
                       CONST name_: string;
                       CONST typ_: T_parameterType;
                       CONST minValue_: double= -infinity;
                       CONST maxValue_: double=  infinity):P_parameterDescription;
    FUNCTION addEnumChildDescription(
                       CONST association_:T_subParameterAssociation;
                       CONST name_,value0,value1: string;
                       CONST value2:string='';
                       CONST value3:string='';
                       CONST value4:string='';
                       CONST value5:string='';
                       CONST value6:string='';
                       CONST value7:string='';
                       CONST value8:string='';
                       CONST value9:string=''):P_parameterDescription;
    FUNCTION subCount:longint;
    FUNCTION getSubDescription(CONST index:longint):P_parameterDescription;
    FUNCTION getSubParameter(CONST index:longint; CONST parentParameter:T_parameterValue):T_parameterValue;
    PROCEDURE setSubParameter(CONST index:longint; VAR parentParameter:T_parameterValue; CONST childParameter:T_parameterValue);
    FUNCTION setDefaultValue(CONST s:string):P_parameterDescription;
    FUNCTION getDefaultParameterValue:T_parameterValue;
    FUNCTION getDefaultParameterString:string;
    FUNCTION areValuesInRange(CONST p:T_parameterValue):boolean;
    PROPERTY getName:string read name;
    PROPERTY getType:T_parameterType read typ;
    PROPERTY getEnumValues:T_arrayOfString read enumValues;
  end;

FUNCTION newParameterDescription(CONST name_: string;
                       CONST typ_: T_parameterType;
                       CONST minValue_: double= -infinity;
                       CONST maxValue_: double=  infinity):P_parameterDescription;
IMPLEMENTATION
USES strutils;
FUNCTION newParameterDescription(CONST name_: string; CONST typ_: T_parameterType; CONST minValue_: double; CONST maxValue_: double): P_parameterDescription;
  begin
    new(result,create(name_,typ_,minValue_,maxValue_));
  end;

FUNCTION T_parameterDescription.shortName:string;
  begin
    result:=ansiReplaceStr(cleanString(name,IDENTIFIER_CHARS,' '),' ','');
  end;

FUNCTION T_parameterDescription.setEnumValues(CONST txt:array of string):P_parameterDescription;
  VAR i:longint;
  begin
    setLength(enumValues,length(txt));
    for i:=0 to length(txt)-1 do enumValues[i]:=txt[i];
    result:=@self;
  end;

FUNCTION T_parameterDescription.addRGBChildParameters:P_parameterDescription;
  begin
    result:=addChildParameterDescription(spa_f0,'R',pt_float)^.
            addChildParameterDescription(spa_f1,'G',pt_float)^.
            addChildParameterDescription(spa_f2,'B',pt_float);
  end;

FUNCTION T_parameterDescription.addHSVChildParameters:P_parameterDescription;
  begin
    result:=addChildParameterDescription(spa_f0,'H',pt_float)^.
            addChildParameterDescription(spa_f1,'S',pt_float)^.
            addChildParameterDescription(spa_f2,'V',pt_float);
  end;

FUNCTION T_parameterDescription.addChildParameterDescription(CONST association_:T_subParameterAssociation; CONST name_: string; CONST typ_: T_parameterType; CONST minValue_: double; CONST maxValue_: double): P_parameterDescription;
  begin
    case association_ of
      spa_filename:   if not(typ_ in [pt_string,pt_fileName]) then exit(nil);
      spa_i0..spa_i3: if (typ_<>pt_integer) then exit(nil);
      spa_f0..spa_f3: if (typ_<>pt_float) then exit(nil);
    end;
    setLength(children,length(children)+1);
    with children[length(children)-1] do begin
      new(description,
        create(name_,typ_,minValue_,maxValue_));
      association:=association_;
    end;
    result:=@self;
  end;

FUNCTION T_parameterDescription.addEnumChildDescription(
                   CONST association_:T_subParameterAssociation;
                   CONST name_,value0,value1: string;
                   CONST value2:string='';
                   CONST value3:string='';
                   CONST value4:string='';
                   CONST value5:string='';
                   CONST value6:string='';
                   CONST value7:string='';
                   CONST value8:string='';
                   CONST value9:string=''):P_parameterDescription;
  VAR subEnumValues:T_arrayOfString=();
  begin
    assert(association_ in [spa_i0..spa_i3]);
    setLength(subEnumValues,2);
    subEnumValues[0]:=value0;
    subEnumValues[1]:=value1;
    if value2<>'' then append(subEnumValues,value2);
    if value3<>'' then append(subEnumValues,value3);
    if value4<>'' then append(subEnumValues,value4);
    if value5<>'' then append(subEnumValues,value5);
    if value6<>'' then append(subEnumValues,value6);
    if value7<>'' then append(subEnumValues,value7);
    if value8<>'' then append(subEnumValues,value8);
    if value9<>'' then append(subEnumValues,value9);
    setLength(children,length(children)+1);
    with children[length(children)-1] do begin
      new(description,
        create(name_,pt_enum,0,length(subEnumValues)-1));
      description^.setEnumValues(subEnumValues);
      association:=association_;
    end;
    result:=@self;
  end;

FUNCTION T_parameterDescription.subCount:longint;
  begin
    result:=length(children);
  end;

FUNCTION T_parameterDescription.getSubDescription(CONST index:longint):P_parameterDescription;
  begin
    result:=children[index].description;
  end;

FUNCTION T_parameterDescription.getSubParameter(CONST index:longint; CONST parentParameter:T_parameterValue):T_parameterValue;
  begin
    with children[index] do case association of
      spa_filename: result.createFromValue(description,parentParameter.fileName);
      spa_i0      : result.createFromValue(description,parentParameter.i0);
      spa_i1      : result.createFromValue(description,parentParameter.i1);
      spa_i2      : result.createFromValue(description,parentParameter.i2);
      spa_i3      : result.createFromValue(description,parentParameter.i3);
      spa_f0      : result.createFromValue(description,parentParameter.f0);
      spa_f1      : result.createFromValue(description,parentParameter.f1);
      spa_f2      : result.createFromValue(description,parentParameter.f2);
      spa_f3      : result.createFromValue(description,parentParameter.f3);
    end;
  end;

PROCEDURE T_parameterDescription.setSubParameter(CONST index:longint; VAR parentParameter:T_parameterValue; CONST childParameter:T_parameterValue);
  begin
    with children[index] do case association of
      spa_filename: parentParameter.fileNameValue:=childParameter.fileName;
      spa_i0      : parentParameter.intValue[0]  :=childParameter.i0;
      spa_i1      : parentParameter.intValue[1]  :=childParameter.i0;
      spa_i2      : parentParameter.intValue[2]  :=childParameter.i0;
      spa_i3      : parentParameter.intValue[3]  :=childParameter.i0;
      spa_f0      : parentParameter.floatValue[0]:=childParameter.f0;
      spa_f1      : parentParameter.floatValue[1]:=childParameter.f0;
      spa_f2      : parentParameter.floatValue[2]:=childParameter.f0;
      spa_f3      : parentParameter.floatValue[3]:=childParameter.f0;
    end;
  end;

FUNCTION T_parameterDescription.setDefaultValue(CONST s:string):P_parameterDescription;
  begin
    defaultValue:=s;
    result:=@self
  end;

FUNCTION T_parameterDescription.getDefaultParameterValue:T_parameterValue;
  begin
    result.createToParse(@self,defaultValue);
  end;

FUNCTION T_parameterDescription.getDefaultParameterString:string;
  begin
    if typ=pt_none
    then result:=name
    else result:=getDefaultParameterValue.toString(tsm_withNiceParameterName);
  end;

FUNCTION T_parameterDescription.areValuesInRange(CONST p:T_parameterValue):boolean;
  VAR i:longint;
  begin
    result:=           (not(typ in I0_RELEVANT_PARAMETER_TYPES) or (p.I0>=minValue) and (p.I0<=maxValue));
    result:=result and (not(typ in I1_RELEVANT_PARAMETER_TYPES) or (p.I1>=minValue) and (p.I1<=maxValue));
    result:=result and (not(typ in I2_RELEVANT_PARAMETER_TYPES) or (p.I2>=minValue) and (p.I2<=maxValue));
    result:=result and (not(typ in I3_RELEVANT_PARAMETER_TYPES) or (p.I3>=minValue) and (p.I3<=maxValue));
    result:=result and (not(typ in F0_RELEVANT_PARAMETER_TYPES) or (p.F0>=minValue) and (p.F0<=maxValue));
    result:=result and (not(typ in F1_RELEVANT_PARAMETER_TYPES) or (p.F1>=minValue) and (p.F1<=maxValue));
    result:=result and (not(typ in F2_RELEVANT_PARAMETER_TYPES) or (p.F2>=minValue) and (p.F2<=maxValue));
    result:=result and (not(typ in F3_RELEVANT_PARAMETER_TYPES) or (p.F3>=minValue) and (p.F3<=maxValue));;
    case typ of
      pt_fileName       : result:=result and isFilename(p.fileNameValue,                SUPPORTED_IMAGE_TYPES    );
      pt_jpgNameWithSize: result:=result and isFilename(p.fileNameValue,T_arrayOfString(SIZE_LIMITABLE_EXTENSION));
    end;
    for i:=0 to length(children)-1 do result:=result and getSubDescription(i)^.areValuesInRange(getSubParameter(i,p));
  end;

VAR PARAMETER_SPLITTERS:T_arrayOfString;

{ T_parameterDescription }

CONSTRUCTOR T_parameterDescription.create(CONST name_: string;
  CONST typ_: T_parameterType; CONST minValue_: double;
  CONST maxValue_: double);
  begin
    defaultValue:='';
    name:=name_;
    typ:=typ_;
    minValue:=minValue_;
    maxValue:=maxValue_;
    setLength(enumValues,0);
    setLength(children,0);
  end;

DESTRUCTOR T_parameterDescription.destroy;
  VAR i:longint;
  begin
    for i:=0 to length(enumValues)-1 do enumValues[i]:='';
    setLength(enumValues,0);
    for i:=0 to length(children)-1 do dispose(children[i].description,destroy);
    setLength(children,0);
  end;

PROCEDURE T_parameterValue.setDefaults;
  VAR i:longint;
  begin
    associatedParmeterDescription:=nil;
    fileNameValue:='';
    for i:=0 to 3 do intValue[i]:=0;
    for i:=0 to 3 do floatValue[i]:=0;
    flagValue:=false;
    valid:=false;
  end;

CONSTRUCTOR T_parameterValue.createCopy(CONST other: P_parameterValue);
  begin
    setDefaults;
    copyFrom(other^,true);
  end;

CONSTRUCTOR T_parameterValue.createToParse(CONST parameterDescription: P_parameterDescription; CONST stringToParse: string; CONST parameterNameMode: T_parameterNameMode);
  begin
    setDefaults;
    associatedParmeterDescription:=parameterDescription;
    canParse(stringToParse,parameterNameMode);
  end;

FUNCTION T_parameterValue.canParse(CONST stringToParse: string;
  CONST parameterNameMode: T_parameterNameMode): boolean;
  VAR txt:string;
      part:T_arrayOfString;
      i:longint;
      expectedPrefix:string;
  begin
    DefaultFormatSettings.DecimalSeparator:='.';
    valid:=false;
    txt:=trim(stringToParse);
    case parameterNameMode of
      tsm_forSerialization:      expectedPrefix:=associatedParmeterDescription^.shortName;
      tsm_withNiceParameterName: expectedPrefix:=associatedParmeterDescription^.name;
      else expectedPrefix:='';
    end;
    if (associatedParmeterDescription^.typ<>pt_none) and (expectedPrefix<>'') then expectedPrefix:=expectedPrefix+':';
    if not(startsWith(txt,expectedPrefix)) then begin
      valid:=false;
      exit(valid);
    end;
    txt:=trim(copy(txt,length(expectedPrefix)+1,length(txt)));
    case associatedParmeterDescription^.typ of
      pt_none: valid:=txt='';
      pt_string: begin
        valid:=txt<>'';
        fileNameValue:=txt;
      end;
      pt_fileName: begin
        if (copy(txt,1,1)=':') then txt:=copy(txt,2,length(txt)-1);
        fileNameValue:=txt;
        valid:=true;
      end;
      pt_jpgNameWithSize: begin
        part:=split(txt,'@');
        if length(part)<2 then valid:=false else begin
          fileNameValue:=part[0];
          if length(part)<>2 then begin valid:=false; exit(valid); end else txt:=part[1];
          if      endsWith(uppercase(txt),'K') then i:=1 shl 10
          else if endsWith(uppercase(txt),'M') then i:=1 shl 20
          else i:=1;
          if i>1 then txt:=copy(txt,1,length(txt)-1);
          try
            intValue[0]:=i*strToInt(txt);
          except
            begin valid:=false; exit(valid); end;
          end;
          valid:=intValue[0]>=0;
        end;
      end;

      pt_enum: begin
        valid:=false;
        for i:=0 to length(associatedParmeterDescription^.enumValues)-1 do if txt=trim(associatedParmeterDescription^.enumValues[i]) then begin
          intValue[0]:=i;
          fileNameValue:=txt;
          valid:=true;
          exit(valid);
        end;
        try
          valid:=true;
          intValue[0]:=strToInt(txt);
        except
          begin valid:=false; exit(valid); end;
        end;
        if (intValue[0]>=0) and (intValue[0]<length(associatedParmeterDescription^.enumValues)) then begin
          fileNameValue:=associatedParmeterDescription^.enumValues[intValue[0]];
          valid:=true;
        end else valid:=false;
      end;
      pt_integer: begin
        try
          valid:=true;
          intValue[0]:=strToInt(txt);
        except
          begin valid:=false; exit(valid); end;
        end;
      end;
      pt_float: begin
        try
          valid:=true;
          floatValue[0]:=strToFloat(txt);
        except
          begin valid:=false; exit(valid); end;
        end;
      end;
      pt_resizeParameter: if startsWith(txt,'x') then begin
        txt:=trim(copy(txt,2,length(txt)-1));
        intValue[0]:=1; intValue[1]:=1;
        floatValue[0]:=strToFloatDef(txt,-1);
        flagValue:=true;
        valid:=floatValue[0]>0;
        exit(valid);
      end else begin
        part:=split(txt,PARAMETER_SPLITTERS);
        floatValue[0]:=1;
        if length(part)<>2 then begin
          valid:=false; exit(false);
        end;
        valid:=true;
        for i:=0 to 1 do begin
          intValue[i]:=strToIntDef(part[i],-1);
          valid:=valid and (intValue[i]>=0);
        end;
      end;
      pt_2integers,pt_3integers,pt_4integers,pt_intOr2Ints,
      pt_2floats,pt_3floats,pt_color,pt_4floats,pt_floatOr2Floats,
      pt_1I3F,pt_1I2F,pt_1I1F,pt_2I2F: begin
        part:=split(txt,PARAMETER_SPLITTERS);
        if not((length(part)=1) and (associatedParmeterDescription^.typ in [pt_floatOr2Floats,pt_intOr2Ints,pt_color])
            or (length(part)=2) and (associatedParmeterDescription^.typ in [pt_2integers,pt_2floats,pt_intOr2Ints,pt_floatOr2Floats,pt_1I1F])
            or (length(part)=3) and (associatedParmeterDescription^.typ in [pt_color,pt_3floats,pt_3integers,pt_1I2F])
            or (length(part)=4) and (associatedParmeterDescription^.typ in [pt_4integers,pt_4floats,pt_1I3F,pt_2I2F])) then begin valid:=false; exit(valid); end;
        valid:=false;
        for i:=0 to length(part)-1 do if (associatedParmeterDescription^.typ in [pt_2integers,pt_3integers,pt_4integers,pt_intOr2Ints])
                                      or (associatedParmeterDescription^.typ in [pt_1I3F,pt_1I2F,pt_1I1F,pt_2I2F]) and (i=0)
                                      or (associatedParmeterDescription^.typ in [                        pt_2I2F]) and (i=1) then
        begin
          try
            intValue[i]:=strToInt(part[i]);
          except
            begin valid:=false; exit(valid); end;
          end;
        end else begin
          try
            floatValue[i]:=strToFloat(part[i]);
          except
            begin valid:=false; exit(valid); end;
          end;
        end;
        if (length(part)=1) and (associatedParmeterDescription^.typ in [pt_floatOr2Floats,pt_color]) then floatValue[1]:=floatValue[0];
        if (length(part)=1) and (associatedParmeterDescription^.typ=pt_color)                        then floatValue[2]:=floatValue[0];
        if (length(part)=1) and (associatedParmeterDescription^.typ=pt_intOr2Ints)                   then intValue  [1]:=intValue  [0];
        valid:=true;
      end;
    end;
    if valid then validate;
    result:=valid;
  end;

PROCEDURE T_parameterValue.validate;
  begin
    valid:=associatedParmeterDescription^.areValuesInRange(self);
  end;

CONSTRUCTOR T_parameterValue.createFromValue(CONST parameterDescription: P_parameterDescription; CONST i0: longint; CONST i1: longint; CONST i2: longint; CONST i3: longint);
  begin
    setDefaults;
    associatedParmeterDescription:=parameterDescription;
    valid:=true;
    intValue[0]:=i0;
    intValue[1]:=i1;
    intValue[2]:=i2;
    intValue[3]:=i3;
    if parameterDescription^.typ=pt_enum then begin
      if (i0>=0) and (i0<length(parameterDescription^.enumValues))
      then fileNameValue:=parameterDescription^.enumValues[i0]
      else valid:=false;
    end;
  end;

CONSTRUCTOR T_parameterValue.createFromValue(
  CONST parameterDescription: P_parameterDescription; CONST f0: double;
  CONST f1: double; CONST f2: double; CONST f3: double);
  begin
    setDefaults;
    associatedParmeterDescription:=parameterDescription;
    floatValue[0]:=f0;
    floatValue[1]:=f1;
    floatValue[2]:=f2;
    floatValue[3]:=f3;
  end;

CONSTRUCTOR T_parameterValue.createFromValue(
  CONST parameterDescription: P_parameterDescription;
  CONST color: T_rgbFloatColor);
  begin
    setDefaults;
    associatedParmeterDescription:=parameterDescription;
    floatValue[0]:=color[cc_red];
    floatValue[1]:=color[cc_green];
    floatValue[2]:=color[cc_blue];
  end;

CONSTRUCTOR T_parameterValue.createFromValue(CONST parameterDescription: P_parameterDescription; CONST txt: string; CONST sizeLimit: longint);
  begin
    setDefaults;
    associatedParmeterDescription:=parameterDescription;
    fileNameValue:=txt;
    intValue[0]:=sizeLimit;
  end;

DESTRUCTOR T_parameterValue.destroy;
  begin
    fileNameValue:='';
  end;

FUNCTION T_parameterValue.toString(CONST parameterNameMode: T_parameterNameMode): string;
  FUNCTION sizeString(CONST sizeInBytes:longint):string;
    begin
      if sizeInBytes=(sizeInBytes shr 20) shl 20 then exit(intToStr(sizeInBytes shr 20)+'M');
      if sizeInBytes=(sizeInBytes shr 10) shl 10 then exit(intToStr(sizeInBytes shr 10)+'k');
      result:=intToStr(sizeInBytes);
    end;

  begin
    DefaultFormatSettings.DecimalSeparator:='.';
    if parameterNameMode=tsm_parameterNameOnly then exit(associatedParmeterDescription^.name);
    case parameterNameMode of
      tsm_forSerialization:      result:=associatedParmeterDescription^.shortName;
      tsm_withNiceParameterName: result:=associatedParmeterDescription^.name;
      else                       result:='';
    end;
    if (associatedParmeterDescription^.typ<>pt_none) and (result<>'') then result+=':';

    case associatedParmeterDescription^.typ of
      pt_fileName,pt_string,pt_enum: result+=fileName;
      pt_jpgNameWithSize:  result+=fileName+'@'+sizeString(intValue[0]);
      pt_integer:          result+=intToStr(intValue[0]);
      pt_2integers:        result+=intToStr(intValue[0])+
                               ','+intToStr(intValue[1]);
      pt_3integers:        result+=intToStr(intValue[0])+
                               ','+intToStr(intValue[1])+
                               ','+intToStr(intValue[2]);
      pt_4integers:        result+=intToStr(intValue[0])+
                               ':'+intToStr(intValue[1])+
                               'x'+intToStr(intValue[2])+
                               ':'+intToStr(intValue[3]);
      pt_float:            result+=floatToStr(floatValue[0]);
      pt_2floats:          result+=floatToStr(floatValue[0])+
                               ','+floatToStr(floatValue[1]);
      pt_3floats:          result+=floatToStr(floatValue[0])+
                               ','+floatToStr(floatValue[1])+
                               ','+floatToStr(floatValue[2]);
      pt_4floats:          result+=floatToStr(floatValue[0])+
                               ':'+floatToStr(floatValue[1])+
                               'x'+floatToStr(floatValue[2])+
                               ':'+floatToStr(floatValue[3]);
      pt_resizeParameter: if flagValue then result+='x'+floatToStr(floatValue[0])
                                       else result+=intToStr(intValue[0])+'x'+intToStr(intValue[1]);
      pt_1I1F:result+=intToStr  (intValue  [0])+
                  ','+floatToStr(floatValue[1]);
      pt_1I2F:result+=intToStr  (intValue  [0])+
                  ','+floatToStr(floatValue[1])+
                  ','+floatToStr(floatValue[2]);
      pt_1I3F:result+=intToStr  (intValue  [0])+
                  ','+floatToStr(floatValue[1])+
                  ','+floatToStr(floatValue[2])+
                  ','+floatToStr(floatValue[3]);
      pt_2I2F:result+=intToStr  (intValue  [0])+
                  ','+intToStr  (intValue  [1])+
                  ','+floatToStr(floatValue[2])+
                  ','+floatToStr(floatValue[3]);
      pt_color: begin
        result+=floatToStr(floatValue[0]);
        if (floatValue[1]<>floatValue[0]) or
           (floatValue[2]<>floatValue[0]) then result+=','+floatToStr(floatValue[1])+
                                                              ','+floatToStr(floatValue[2]);
      end;
      pt_floatOr2Floats: begin
        result+=floatToStr(floatValue[0]);
        if floatValue[1]<>floatValue[0] then result+=','+floatToStr(floatValue[1]);
      end;
      pt_intOr2Ints: begin
        result+=intToStr(intValue[0]);
        if intValue[1]<>intValue[0] then result+=','+floatToStr(intValue[1]);
      end;

    end;
  end;

PROCEDURE T_parameterValue.setFileName(CONST newValue: string);
  begin
    fileNameValue:=newValue;
    validate;
  end;

FUNCTION T_parameterValue.getNumericParameter(CONST index: byte): double;
  begin
    case index of
      0: if associatedParmeterDescription^.typ in I0_RELEVANT_PARAMETER_TYPES then result:=intValue  [0] else
         if associatedParmeterDescription^.typ in F0_RELEVANT_PARAMETER_TYPES then result:=floatValue[0] else result:=0;
      1: if associatedParmeterDescription^.typ in I1_RELEVANT_PARAMETER_TYPES then result:=intValue  [1] else
         if associatedParmeterDescription^.typ in F1_RELEVANT_PARAMETER_TYPES then result:=floatValue[1] else result:=0;
      2: if associatedParmeterDescription^.typ in I2_RELEVANT_PARAMETER_TYPES then result:=intValue  [2] else
         if associatedParmeterDescription^.typ in F2_RELEVANT_PARAMETER_TYPES then result:=floatValue[2] else result:=0;
      3: if associatedParmeterDescription^.typ in I3_RELEVANT_PARAMETER_TYPES then result:=intValue  [3] else
         if associatedParmeterDescription^.typ in F3_RELEVANT_PARAMETER_TYPES then result:=floatValue[3] else result:=0;
    else result:=0;
    end;
  end;

PROCEDURE T_parameterValue.setNumericParameter(CONST index:byte; CONST value:double);
  begin
    case index of
      0: if associatedParmeterDescription^.typ in I0_RELEVANT_PARAMETER_TYPES then intValue  [0]:=round(value) else
         if associatedParmeterDescription^.typ in F0_RELEVANT_PARAMETER_TYPES then floatValue[0]:=      value;
      1: if associatedParmeterDescription^.typ in I1_RELEVANT_PARAMETER_TYPES then intValue  [1]:=round(value) else
         if associatedParmeterDescription^.typ in F1_RELEVANT_PARAMETER_TYPES then floatValue[1]:=      value;
      2: if associatedParmeterDescription^.typ in I2_RELEVANT_PARAMETER_TYPES then intValue  [2]:=round(value) else
         if associatedParmeterDescription^.typ in F2_RELEVANT_PARAMETER_TYPES then floatValue[2]:=      value;
      3: if associatedParmeterDescription^.typ in I3_RELEVANT_PARAMETER_TYPES then intValue  [3]:=round(value) else
         if associatedParmeterDescription^.typ in F3_RELEVANT_PARAMETER_TYPES then floatValue[3]:=      value;
    end;
  end;

FUNCTION T_parameterValue.color: T_rgbFloatColor;
  begin
    result:=rgbColor(floatValue[0],floatValue[1],floatValue[2]);
  end;

FUNCTION T_parameterValue.strEq(CONST other: T_parameterValue): boolean;
  begin
    result:=toString(tsm_forSerialization)=other.toString(tsm_forSerialization);
  end;

FUNCTION T_parameterValue.interpolate(CONST other: T_parameterValue;
  CONST step: double): T_parameterValue;
  begin
    result.createFromValue(associatedParmeterDescription,
      f0*(1-step)+other.f0*step,
      f1*(1-step)+other.f1*step,
      f2*(1-step)+other.f2*step,
      f3*(1-step)+other.f3*step);
    result.fileNameValue:=fileNameValue;
    result.intValue:=intValue;
  end;

PROCEDURE T_parameterValue.modifyI(CONST index: longint; CONST value: longint);
  begin
    intValue[index]:=value;
    validate;
  end;

PROCEDURE T_parameterValue.modifyF(CONST index: longint; CONST value: double);
  begin
    floatValue[index]:=value;
    validate;
  end;

PROCEDURE T_parameterValue.copyFrom(CONST other: T_parameterValue; CONST forceParameterDescription: boolean=false);
  begin
    fileNameValue:=other.fileNameValue;
    intValue     :=other.intValue     ;
    floatValue   :=other.floatValue   ;
    valid        :=other.valid        ;
    if forceParameterDescription
    then associatedParmeterDescription:=other.associatedParmeterDescription
    else if associatedParmeterDescription<>other.associatedParmeterDescription
         then raise Exception.create('Copying values from instance with another associated parameter description');
  end;

INITIALIZATION
  PARAMETER_SPLITTERS:=',';
  append(PARAMETER_SPLITTERS,':');
  append(PARAMETER_SPLITTERS,'x');
  DefaultFormatSettings.DecimalSeparator:='.';

end.
