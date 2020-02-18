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
  CONST DEFAULT_COLOR_TABLE:array[0..255] of T_rgbFloatColor=(
(0,0,0),(1,1,1),(0,0,1),(0,1,0),(1,0,0),(1,1,0),(1,0,1),(0,1,1),
(0.5,0.5,0.5),(0.25,0.25,0.75),(0.75,0.75,0.75),(0,0.6875,0),(1,0.3125,0),(0.4375,0.875,0),(0.5625,0.125,0),(1,0.5625,0),
(0,0.4375,0),(0.0625,0.8125,1),(0.9375,0.1875,1),(0,0.5625,1),(1,0.4375,1),(0.5,0,0.8125),(0.5,1,0.8125),(0.6875,0.3125,1),
(0.3125,0.6875,1),(0.5625,0.625,0),(0.0625,0.125,0.5),(0.4375,0.375,0),(0.9375,0.875,0.5),(0.8125,0.625,1),(0.1875,0.375,1),(0,0.3125,0),
(1,0.6875,0),(0.625,0.25,0),(0.375,0.75,0),(0,0.875,0),(1,0.125,0),(0.8125,0.4375,0),(0.1875,0.5625,0),(0.5625,0.1875,0.9375),
(0.4375,0.8125,0.9375),(0.3125,0.0625,0.25),(0.6875,0.9375,0.25),(0.25,0.9375,0.5625),(0.75,0.0625,0.5625),(0.25,0.1875,0),(0.75,0.8125,0),(0.3125,0.5625,0.9375),
(0,0.6875,0.9375),(1,0.3125,0.9375),(0.6875,0.4375,0.9375),(0.375,1,0),(0.625,0,0),(0.3125,0.125,1),(0.6875,0.875,1),(0.75,0.5625,0.4375),
(0.25,0.4375,0.4375),(0.1875,0.8125,0.1875),(0.8125,0.1875,0.1875),(0,0.3125,0.875),(1,0.6875,0.875),(1,0.5625,0.875),(0,0.4375,0.875),(0.4375,0.3125,0.5625),
(0.5625,0.6875,0.5625),(0,0.1875,1),(1,0.8125,1),(0.125,0.625,0.5),(0.875,0.375,0.5),(0.8125,0.25,0.6875),(0.1875,0.75,0.6875),(0.5,0.625,1),
(0.0625,0.5,0.4375),(0.9375,0.5,0.4375),(0.5,0.375,1),(0.75,0.3125,0.25),(0.25,0.6875,0.25),(1,0.625,0.4375),(0,0.25,0.4375),(0,0.375,0.4375),
(0.75,0.125,1),(0.25,0.875,1),(1,0.75,0.4375),(0.25,0,0.625),(0.75,1,0.625),(0,0.9375,0.4375),(1,0.0625,0.4375),(0.25,0.3125,0.0625),
(0.75,0.6875,0.0625),(0,0.1875,0),(0.75,0,1),(0.25,1,1),(1,0.8125,0),(0.125,0.0625,0.875),(0.5625,0.4375,0.125),(0.4375,0.5625,0.125),
(0.875,0.9375,0.875),(0.375,0.25,0.125),(0.625,0.75,0.125),(0.6875,0.5,0),(0.3125,0.5,0),(0,0.875,0.75),(0.5,0.8125,0.25),(0.3125,0.625,0),
(0.625,1,0),(0.5,0.1875,0.25),(0.6875,0.375,0),(1,0.125,0.75),(0.375,0,0),(0.5,0.25,0.75),(0.0625,0.0625,0.1875),(0.5625,0.9375,1),
(0.9375,0.9375,0.1875),(0.5,0.75,0.75),(0.4375,0.0625,1),(0.125,0.75,0),(0.875,0.25,0),(0.375,0.4375,1),(0.625,0.5625,1),(0.1875,0.5,1),
(0.8125,0.5,1),(0.8125,0,0.375),(0.375,0.125,0.375),(0.1875,0.1875,0.625),(0.5,0.875,0.625),(0.8125,0.8125,0.625),(0.1875,1,0.375),(0.1875,0.375,0),
(0.8125,0.625,0),(0.1875,0.875,0.375),(0.25,0.3125,0.9375),(0.75,0.6875,0.9375),(0.6875,0.875,0.0625),(0.4375,0.9375,0.1875),(0.8125,0.125,0.375),(0.5625,0.0625,0.1875),
(1,0.4375,0.3125),(0,0.5625,0.3125),(0.5625,0.125,0.6875),(1,0.25,1),(0,0.75,1),(0.25,0.625,1),(0.75,0.375,1),(0.1875,0.125,0),
(0.3125,0.375,0.5),(0.6875,0.625,0.5),(1,0.375,0),(0,0.625,1),(1,0.375,1),(0,0.625,0),(0.4375,0.6875,0),(0.5625,0.3125,0),
(0.1875,0.9375,0),(1,0.1875,0.4375),(0.9375,0.75,1),(0.9375,0.0625,1),(0.0625,0.25,1),(0.8125,0.0625,0),(0.0625,0.9375,1),(0,0.8125,0.4375),
(0.25,0.8125,0.75),(0.75,0.1875,0.75),(0.375,0.625,0.5625),(0.875,0.75,0),(0.625,0.375,0.5625),(0.125,0.25,0),(0.375,0.1875,0.8125),(0.625,0.8125,0.75),
(0.375,0.4375,0),(0.625,0.5625,0),(0,0.75,0.4375),(1,0.25,0.4375),(0.1875,0,0.0625),(0.625,0.5,0.9375),(0.3125,0.5,0.5625),(0.8125,1,0.0625),
(0.1875,0.4375,1),(0.375,0.9375,1),(0.8125,0.5625,1),(1,0.625,1),(1,0.5,1),(0,0.5,1),(0,0.375,1),(0.625,0.0625,1),
(0,0.125,1),(0,0.125,0),(0.75,0.5,0.5),(0.0625,0,0.5),(0.875,0.875,0),(0.9375,1,0.5),(1,0.875,1),(0.4375,0.5,1),
(0.5,0.5625,0.625),(0.125,0.3125,0.4375),(0.1875,0.5625,0.5625),(0.4375,0.4375,0.5),(0.8125,0.4375,0.5625),(0.875,0.6875,0.5),(0.5,0.5,0),(0,0.1875,0.5),
(1,0.8125,0.5),(1,0,0.5),(0,1,0.5),(0.5,1,0.3125),(0.125,0.6875,0.625),(0.3125,0.75,1),(0.625,0,0.5),(0.875,0.3125,0.625),
(0.6875,0.25,1),(0,0.5,0),(0.8125,0.5625,0),(0.9375,0.5625,0.4375),(0.75,0.875,0.5625),(0.375,0.6875,0.5625),(0.5,0.6875,1),(0.5,0.3125,1),
(0.0625,0.4375,0.4375),(0.875,0.5,0),(0.1875,0.4375,0),(0.625,0.3125,0.5625),(0.625,0.1875,0.5),(0.3125,0.0625,0.75),(0.5,0,0.25),(0,0.0625,0.625),
(0.625,0.1875,0),(0.5625,0.9375,0.5),(1,0.9375,0.625),(0.375,0.8125,0.5),(0.625,0.75,1),(0.3125,0.75,0.4375),(0.6875,0.25,0.4375),(0.1875,0.125,0.75),
(0.375,0.8125,0),(0.6875,0.9375,0.75),(0.375,1,0.5625),(0.375,0.25,1),(0.4375,0.0625,0.5),(1,0.0625,0),(0,0.375,0),(1,0.625,0),
(0,0.8125,0),(1,0.1875,0),(0,0.9375,0),(0.625,0.4375,0.5625),(0.75,0.8125,1),(0.125,0.1875,0.25),(0.3125,0.1875,0.375),(0.1875,0,1),
(0.375,0.875,0.375),(0.1875,0.0625,0.5),(0.125,1,0.75),(0.8125,0.75,0.375),(0.8125,0.9375,0.5),(0.75,0.125,0),(0.1875,0.25,0.375),(0.875,0,0.75));
  CONST BOUNDS_COLOR_TABLE:array[0..255] of T_rgbFloatColor=(
  (0,0,0),(1,1,1),(0,0,1),(0,1,0),(1,0,0),(1,1,0),(1,0,1),(0,1,1),
  (0.0363033153116703,0.54397082328796387,0.5282526612281799),(0.9757430553436279,0.666578471660614,0.5106348395347595),(0.021566959097981453,0.024633187800645828,0.5423933863639831),(0.76236093044281006,0.49265187978744507,0.20658473670482635),(0.050049275159835815,0.51316624879837036,0.9568444490432739),(0.98795944452285767,0.51532495021820068,0.91962742805480957),(0.951995313167572,0.007259123958647251,0.5911556482315063),(0.013361900113523006,0.44375014305114746,0.13422054052352905),
  (0.04785908758640289,0.9486427903175354,0.6073615550994873),(0.37729519605636597,0.9939723014831543,0.28832268714904785),(0.63400536775588989,0.9726060628890991,0.7808117866516113),(0.5736945867538452,0.08352076262235641,0.32458049058914185),(0.58424502611160278,0.46142828464508057,0.6964324116706848),(0.13345220685005188,0.222475066781044,0.7504867315292358),(0.0247688926756382,0.7999131083488464,0.2592950165271759),(0.7258658409118652,0.7996507883071899,0.019597161561250687),
  (0.9064650535583496,0.9799690246582031,0.374510794878006),(0.42482230067253113,0.5718151330947876,0.0023120422847568989),(0.046078428626060486,0.14225810766220093,0.2524752616882324),(0.8621358275413513,0.33004578948020935,0.44585344195365906),(0.44840338826179504,0.07205233722925186,0.9963341951370239),(0.39228299260139465,0.070525713264942169,0.02043592743575573),(0.68701714277267456,0.36195534467697144,0.9834311008453369),(0.43326038122177124,0.79230982065200806,0.7794334292411804),
  (0.653863787651062,0.17166663706302643,0.81803959608078),(0.42205497622489929,0.4017502963542938,0.26615205407142639),(0.9982333779335022,0.15517869591712952,0.18435467779636383),(0.44646346569061279,0.986880362033844,0.532806932926178),(0.45345032215118408,0.714235246181488,0.42122164368629456),(0.9652127623558044,0.660622239112854,0.238549143075943),(0.019596610218286514,0.0074008256196975708,0.77431505918502808),(0.01249453704804182,0.7344570159912109,0.7829155325889587),
  (0.9796837568283081,0.97053921222686768,0.6062805652618408),(0.17423827946186066,0.24376969039440155,0.5119853019714355),(0.587191104888916,0.852507472038269,0.9997780919075012),(0.95614266395568848,0.5284675359725952,0.70152944326400757),(0.20264947414398193,0.42903679609298706,0.7248638272285461),(0.25002947449684143,0.678371250629425,0.9995481967926025),(0.9980776309967041,0.31801387667655945,0.031210754066705704),(0.9911847710609436,0.993198812007904,0.807071328163147),
  (0.87024778127670288,0.9319573044776916,0.18902216851711273),(0.5172722339630127,0.25293582677841187,0.03848372399806976),(0.4174792468547821,0.7766730189323425,0.1534970998764038),(0.06498128920793533,0.3820180296897888,0.33716309070587158),(0.5777594447135925,0.23078060150146484,0.4985813498497009),(0.53349798917770386,0.00386658962816,0.6052364706993103),(0.99541389942169189,0.19786876440048218,0.7344531416893005),(0.99816370010375977,0.7423443794250488,0.87304478883743286),
  (0.18164312839508057,0.686846911907196,0.5701934695243835),(0.9722078442573547,0.47473233938217163,0.3457164466381073),(0.640964150428772,0.61718970537185669,0.5819386839866638),(0.016374729573726654,0.28465011715888977,0.9711900949478149),(0.27532041072845459,0.005751579999923706,0.8681765794754028),(0.25081071257591248,0.03379935398697853,0.3933744430541992),(0.1142914742231369,0.6106193661689758,0.16145850718021393),(0.6564255952835083,0.522704005241394,0.8385035395622253),
  (0.03810920938849449,0.95033514499664307,0.36169666051864624),(0.680799663066864,0.035085953772068024,0.12191810458898544),(0.40060752630233765,0.48685771226882935,0.4222758412361145),(0.89601677656173706,0.7593666315078735,0.6804718971252441),(0.98842734098434448,0.0036819004453718662,0.4067872166633606),(0.8224726915359497,0.5694776177406311,0.03019663318991661),(0.9909389019012451,0.37388110160827637,0.5734642148017883),(0.2838848829269409,0.99878418445587158,0.05109260231256485),
  (0.003061715979129076,0.9750796556472778,0.809058666229248),(0.3097715377807617,0.9964736700057983,0.8744055032730102),(0.55299597978591919,0.22707511484622955,0.98405367136001587),(0.726559579372406,0.80585688352584839,0.37837398052215576),(0.025144018232822418,0.70051097869873047,0.40319320559501648),(0.01634819060564041,0.59471261501312256,0.00043968250975012779),(0.80097496509552,0.25900903344154358,0.59195917844772339),(0.52145415544509888,0.17901457846164703,0.6609033942222595),
  (0.00015363027341663837,0.80183756351470947,0.02981562167406082),(0.39124932885169983,0.46547794342041016,0.8509711623191833),(0.58938699960708618,0.6510040163993835,0.97706925868988037),(0.7025376558303833,0.9906419515609741,0.98644977807998657),(0.24413254857063293,0.23789533972740173,0.2047235369682312),(0.4096734821796417,0.43586358428001404,0.5996604561805725),(0.07681845873594284,0.060231540352106094,0.1189483106136322),(0.6607285141944885,0.98035728931427,0.6259239912033081),
  (0.11332565546035767,0.12041608989238739,0.6420708298683166),(0.9933502674102783,0.8202087879180908,0.031317830085754395),(0.574546217918396,0.013678636401891708,0.8267337679862976),(0.016688620671629906,0.96318131685256958,0.14972800016403198),(0.6181174516677856,0.35141193866729736,0.12195871770381927),(0.79485124349594116,0.2916845679283142,0.31354221701622009),(0.665005624294281,0.6674160361289978,0.2816181480884552),(0.3190738260746002,0.9573346376419067,0.6702345013618469),
  (0.4197075366973877,0.006824499927461147,0.16907909512519836),(0.67205500602722168,0.8683314323425293,0.16696397960186005),(0.011540033854544163,0.33906778693199158,0.021537581458687782),(0.45522201061248779,0.5606117248535156,0.15822426974773407),(0.93078446388244629,0.877373993396759,0.50553703308105469),(0.2516897916793823,0.2951768636703491,0.8740521669387817),(0.012409227900207043,0.3754889965057373,0.64123225212097168),(0.029820069670677185,0.81649231910705566,0.90055686235427856),
  (0.40292251110076904,0.6179688572883606,0.32562696933746338),(0.803609311580658,0.6985329985618591,0.8285308480262756),(0.38075363636016846,0.6804072856903076,0.70422631502151489),(0.018783165141940117,0.5641320943832397,0.30028071999549866),(0.37315866351127625,0.7988239526748657,0.018451133742928505),(0.57703828811645508,0.21762280166149139,0.20182487368583679),(0.2394752949476242,0.9585124850273132,0.44118255376815796),(0.56012576818466187,0.08457721024751663,0.46704497933387756),
  (0.9844720363616943,0.3539566397666931,0.86828887462615967),(0.27590945363044739,0.38707822561264038,0.40217140316963196),(0.94294184446334839,0.012547992169857025,0.18442080914974213),(0.967059314250946,0.033581819385290146,0.721257209777832),(0.07952914386987686,0.8389551043510437,0.4776395559310913),(0.57249772548675537,0.529914915561676,0.4911207854747772),(0.56232571601867676,0.793528139591217,0.49714255332946777),(0.2998838722705841,0.45974665880203247,0.05918178707361221),
  (0.9433443546295166,0.14864784479141235,0.8816551566123962),(0.010504506528377533,0.6174286007881164,0.6762067675590515),(0.6551048159599304,0.9996063709259033,0.31966185569763184),(0.29799097776412964,0.8306130170822143,0.9267838597297668),(0.93620592355728149,0.1722801923751831,0.043266333639621735),(0.62658524513244629,0.22012150287628174,0.34627801179885864),(0.9274322986602783,0.66546875238418579,0.11019603908061981),(0.002626500092446804,0.01963820308446884,0.35163822770118713),
  (0.024969719350337982,0.57968336343765259,0.8244046568870544),(0.7903597354888916,0.0005562345031648874,0.908444344997406),(0.40735742449760437,0.018950846046209335,0.7322949171066284),(0.9899041652679443,0.8049744963645935,0.35223859548568726),(0.1572951078414917,0.77126860618591309,0.12635371088981628),(0.08390536159276962,0.14587755501270294,0.0004165449645370245),(0.7827429175376892,0.46008598804473877,0.99991798400878906),(0.59145009517669678,0.27836811542510986,0.70411014556884766),
  (0.62370932102203369,0.7901729941368103,0.674920916557312),(0.0024708271957933903,0.23578916490077972,0.438882440328598),(0.7751073837280273,0.6395542025566101,0.41742891073226929),(0.026468407362699509,0.24720369279384613,0.12709277868270874),(0.21922996640205383,0.9610663056373596,0.22152523696422577),(0.6781078577041626,0.99237912893295288,0.040296841412782669),(0.985831618309021,0.3559650182723999,0.7282588481903076),(0.061808276921510696,0.19436879456043243,0.8690093159675598),
  (0.93848270177841187,0.70199304819107056,0.9934556484222412),(0.11538159847259521,0.10928770154714584,0.99981963634490967),(0.72435265779495239,0.4683144688606262,0.33079659938812256),(0.3067168593406677,0.05869760364294052,0.51695519685745239),(0.77237427234649658,0.32728874683380127,0.83551180362701416),(0.1666317582130432,0.42123645544052124,0.22228394448757172),(0.32071173191070557,0.676490306854248,0.82693922519683838),(0.9663598537445068,0.53088849782943726,0.5239818692207336),
  (0.09228193014860153,0.6308205127716064,0.9706597328186035),(0.9948586225509643,0.19892685115337372,0.97628039121627808),(0.7207343578338623,0.023890838027000427,0.7210712432861328),(0.30733263492584229,0.21863740682601929,0.3979411721229553),(0.37395665049552917,0.77815806865692139,0.61469602584838867),(0.28429386019706726,0.5379807353019714,0.7427933812141418),(0.26831233501434326,0.3561529815196991,0.56615686416625977),(0.37321650981903076,0.830581784248352,0.2985934019088745),
  (0.6925527453422546,0.5566400289535522,0.6988921761512756),(0.9256547093391418,0.14717961847782135,0.48033860325813293),(0.6030696630477905,0.8863110542297363,0.879081666469574),(0.05862355977296829,0.83996683359146118,0.7293928861618042),(0.92193341255187988,0.11635234206914902,0.30477282404899597),(0.6059896349906921,0.08256042748689651,0.0064084082841873169),(0.2071530520915985,0.33981812000274658,0.987352192401886),(0.97447353601455688,0.90852946043014526,0.7310317754745483),
  (0.3695836067199707,0.3993127942085266,0.9642522931098938),(0.26437529921531677,0.66084080934524536,0.4555845558643341),(0.6578279137611389,0.370713472366333,0.005104025825858116),(0.66269075870513916,0.96359521150588989,0.4457784593105316),(0.25576809048652649,0.2309250384569168,0.06647653132677078),(0.9396166205406189,0.53002959489822388,0.16682219505310059),(0.8599547147750854,0.34749433398246765,0.15794101357460022),(0.017753787338733673,0.39801740646362305,0.7792360186576843),
  (0.68979710340499878,0.4622599184513092,0.06586089730262756),(0.8287053108215332,0.49008014798164368,0.4518733024597168),(0.35316067934036255,0.09026330709457397,0.26621749997138977),(0.0200616754591465,0.5725690126419067,0.4093298614025116),(0.98285913467407227,0.91029602289199829,0.922154426574707),(0.63975262641906738,0.3314380645751953,0.49645623564720154),(0.61282718181610107,0.83974546194076538,0.7785071730613708),(0.07360801845788955,0.247469961643219,0.30899029970169067),
  (0.3274778127670288,0.17418335378170013,0.6118943691253662),(0.8687751293182373,0.91102749109268188,0.84020346403121948),(0.45721027255058289,0.4861159324645996,0.9410569667816162),(0.79117941856384277,0.02618882991373539,0.514430582523346),(0.29122084379196167,0.5506908297538757,0.3100823163986206),(0.10557626187801361,0.43392887711524963,0.004910292103886604),(0.75346261262893677,0.6881833672523498,0.9725044965744018),(0.021884676069021225,0.13857577741146088,0.77122014760971069),
  (0.30089488625526428,0.26814448833465576,0.7540326118469238),(0.96598118543624878,0.7912020087242126,0.23822700977325439),(0.75223875045776367,0.81580489873886108,0.5867806077003479),(0.97944647073745728,0.36681100726127625,0.26305139064788818),(0.6090816855430603,0.612014651298523,0.11174916476011276),(0.27810028195381165,0.95822340250015259,0.7798759341239929),(0.031998194754123688,0.024240698665380478,0.23052015900611877),(0.27346006035804749,0.94196921586990356,0.98557132482528687),
  (0.40584924817085266,0.3309175372123718,0.80852305889129639),(0.76358979940414429,0.12225903570652008,0.08099088072776794),(0.7295216917991638,0.2478661686182022,0.23797613382339478),(0.4848981499671936,0.56629049777984619,0.60068988800048828),(0.41452479362487793,0.973608672618866,0.14607737958431244),(0.0034013045951724052,0.4392813444137573,0.50488477945327759),(0.28471672534942627,0.34195098280906677,0.1164669319987297),(0.5706774592399597,0.4477402865886688,0.2793375253677368),
  (0.9870098829269409,0.99940037727355957,0.26562052965164185),(0.9522769451141357,0.03960871696472168,0.8374456763267517),(0.40941101312637329,0.98888051509857178,0.43026119470596313),(0.99438703060150146,0.42110943794250488,0.08391236513853073),(0.97063952684402466,0.989320695400238,0.10484597086906433),(0.572685718536377,0.75431925058364868,0.9004107117652893),(0.66104716062545776,0.8039482235908508,0.26624822616577148),(0.99159586429595947,0.77152347564697266,0.13527093827724457),
  (0.0013160952366888523,0.057971172034740448,0.8936913013458252),(0.7226840853691101,0.6001697182655334,0.87616723775863647),(0.9951363205909729,0.10382231324911118,0.6314652562141418),(0.19177104532718658,0.7770366072654724,0.37102779746055603),(0.15610919892787933,0.6461207270622253,0.031395789235830307),(0.52805906534194946,0.65073603391647339,0.2196473628282547),(0.3219461441040039,0.10544884949922562,0.91557610034942627),(0.64309823513031006,0.75409716367721558,0.10956374555826187),
  (0.9223607778549194,0.4802890121936798,0.7971875667572021),(0.96033614873886108,0.63620674610137939,0.7315106391906738),(0.79335558414459229,0.19658270478248596,0.97994011640548706),(0.4748670160770416,0.86458313465118408,0.378531813621521),(0.77702599763870239,0.019561730325222015,0.3920759856700897),(0.53988867998123169,0.1330125629901886,0.9173663258552551),(0.9441471695899963,0.6383654475212097,0.004805255681276321),(0.9415991902351379,0.8330186009407043,0.6116657257080078),
  (0.70847797393798828,0.6304182410240173,0.7727506160736084),(0.4061506390571594,0.22794976830482483,0.28444743156433105),(0.31232768297195435,0.8931300044059753,0.54727202653884888),(0.10533709079027176,0.8320554494857788,0.9821815490722656),(0.45903998613357544,0.97940433025360107,0.72106671333312988),(0.093934878706932068,0.98462140560150146,0.89631897211074829),(0.22587919235229492,0.88179945945739746,0.71293181180953979),(0.0019525161478668451,0.56420904397964478,0.1239907294511795),
  (0.6233550906181335,0.34823113679885864,0.39905646443367004),(0.9944154024124145,0.68871009349823,0.40128040313720703),(0.7967029213905334,0.65038752555847168,0.593936026096344),(0.049787480384111404,0.6746346354484558,0.5003550052642822),(0.22726912796497345,0.01672409102320671,0.71070235967636108),(0.5175024271011352,0.29023224115371704,0.6140102744102478),(0.8768907785415649,0.29214492440223694,0.66214889287948608),(0.05308789014816284,0.059896327555179596,0.45024162530899048),
  (0.72205781936645508,0.067794248461723328,0.24025316536426544),(0.44761812686920166,0.9920133352279663,0.959690272808075),(0.15257427096366882,0.8414376974105835,0.27753308415412903),(0.026958020403981209,0.32902055978775024,0.877229630947113),(0.2584044337272644,0.6956260204315185,0.21370285749435425),(0.6205315589904785,0.99622488021850586,0.14947611093521118),(0.8218013048171997,0.8183167576789856,0.47330492734909058),(0.7386553883552551,0.41901370882987976,0.5510010719299316));
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

  PROCEDURE medianCutColors;
    //Variance based spreads
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
          spread:=rgbColor(sqrt(rr/count-sqr(r/count))*count,
                           sqrt(gG/count-sqr(g/count))*count,
                           sqrt(bb/count-sqr(b/count))*count);
          maxSpread:=max(spread[cc_red],max(spread[cc_green],spread[cc_blue]));
        end;
      end;

    PROCEDURE split(VAR list:T_colorList; CONST threefold:boolean; OUT halfList,thirdList:T_colorList);
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
        if threefold then begin
          splitCount:=popCount div 3;
          i0:=0; popCount:=0;
          while (popCount<splitCount) do begin
            popCount+=list.sample[i0].count; inc(i0);
          end;

          setLength(thirdList.sample,i0);
          for i:=0 to i0-1 do thirdList.sample[i]:=list.sample[i];
          updateSpreads(thirdList);

          popCount:=0;
          for i:=i0 to length(list.sample)-1 do begin
            list.sample[i-i0]:=list.sample[i];
            popCount+=list.sample[i].count;
          end;
          setLength(list.sample,length(list.sample)-i0);

        end;
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

    VAR buckets:array of T_colorList;
    PROCEDURE splitOneList(CONST threefold:boolean);
      VAR i:longint;
          toSplit:longint=0;

      begin
        for i:=1 to length(buckets)-1 do if buckets[i].maxSpread>buckets[toSplit].maxSpread then toSplit:=i;
        i:=length(buckets);
        setLength(buckets,i+2);
        split(buckets[toSplit],threefold,buckets[i],buckets[i+1]);
        if not(threefold) then setLength(buckets,i+1);
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

    VAR k:longint;
    begin
      setLength(buckets,1);
      buckets[0]:=firstBucket;
      while (length(buckets)<parameters.i0) and not context^.cancellationRequested do splitOneList(false);
      setLength(colorTable,length(buckets));
      for k:=0 to length(buckets)-1 do begin
        colorTable[k]:=averageColor(buckets[k]);
        setLength(buckets[k].sample,0);
      end;
      setLength(buckets,0);
    end;

  PROCEDURE kMeansColorTable;
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
      end;

    VAR allSamples:T_colorList;
        buckets:array of T_colorList;
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

    VAR i:longint;
    begin
      allSamples:=firstBucket;
      setLength(buckets,parameters.i0);
      for i:=0 to length(buckets)-1 do buckets[i].spread:=DEFAULT_COLOR_TABLE[i];
      nextDefaultColor:=length(buckets);
      i:=0;
      while redistributeSamples and (i<50) do inc(i);
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
      for k:=0 to length(colorTable)-1 do colorTable[k]:=BOUNDS_COLOR_TABLE[k];
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
      for y:=0 to ym do for x:=0 to xm do begin
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
        if (x>=0) and (x<=xm) and (y>=0) and (y<=ym) then begin
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

