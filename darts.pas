UNIT darts;
INTERFACE
CONST darts_delta:array[0..507,0..1] of single=(
( 0.00000000000000E+000, 0.00000000000000E+000),(-4.97259820345789E-001,-4.97061351081357E-001),( 4.98133498243988E-001, 5.58271678164601E-003),
( 8.48103757016361E-003, 4.89616230130196E-001),( 2.53802068531513E-001,-2.49710366595537E-001),(-2.49359282664955E-001, 2.52228151774034E-001),
(-2.52912004245445E-001,-2.42797511396930E-001),( 2.54372373456135E-001, 2.53523220075294E-001),( 2.48879090184346E-001, 5.43342623859644E-003),
(-6.47273054346442E-003,-2.48792433179915E-001),(-2.37596001010388E-001,-4.98886368004605E-001),(-4.98293236829341E-001, 2.53365785349160E-001),
( 2.55573871079832E-001,-4.96483526891098E-001),(-4.98130416730419E-001,-2.51255956245586E-001),(-7.36635923385620E-003, 2.48295750468969E-001),
(-2.52955130767077E-001, 1.99752068147063E-003),(-3.65670953411609E-001,-3.79491089144722E-001),(-3.75681213103235E-001, 1.27375516109169E-001),
( 1.25668199267238E-001,-3.70469306828454E-001),( 1.24564168741927E-001,-1.35202639503405E-001),( 1.21371326968074E-001, 1.21413437649608E-001),
( 3.79449175670743E-001, 1.30608858540654E-001),( 3.73252873308957E-001, 3.77695463830605E-001),(-1.28836066927761E-001, 1.20140564627945E-001),
( 3.78544151317328E-001,-1.15717149106786E-001),( 3.76142388442531E-001,-3.74801095807925E-001),(-3.73374232789502E-001, 3.69626813568175E-001),
(-3.73152238084003E-001,-1.22927034040913E-001),(-1.27603467553854E-001,-1.18564734235406E-001),(-1.13742452347651E-001,-3.79956755088642E-001),
( 1.29915253957734E-001, 3.73448160244152E-001),(-1.19520800421014E-001, 3.78092288039625E-001),(-4.97726101893932E-001,-1.26235608942807E-001),
(-3.71071927715093E-001, 4.95217859512195E-001),( 4.96633941307664E-001, 3.76578457187861E-001),( 3.76935431733728E-001,-2.51771402778104E-001),
( 1.15224396111444E-001, 2.44349385611713E-001),( 2.49962122645229E-001,-3.73705533100292E-001),( 2.47876795707271E-001, 1.29590393044055E-001),
(-2.43520284537226E-001,-3.72773363254964E-001),(-4.25273738801479E-003, 1.22675278456882E-001),( 2.53390252124518E-001,-1.16945496993139E-001),
(-3.80863585043699E-001,-1.22309639118612E-003),( 1.27036745194346E-001,-1.31567262578756E-002),(-2.52312917727977E-001, 3.79934897180647E-001),
(-4.92234106641263E-001,-3.73404062585905E-001),( 3.75094065908343E-001, 7.82909663394094E-003),(-1.30766520975158E-001,-2.43963791988790E-001),
( 3.76242716796696E-001,-4.95679049985483E-001),(-3.74102988513187E-001,-2.46269589057192E-001),( 2.52182963769883E-001, 3.82135910680518E-001),
( 4.16232505813241E-004,-1.29277325933799E-001),( 1.34941767202690E-001,-4.97428214875981E-001),( 3.79827633267269E-001, 2.56173175759614E-001),
(-1.30499377846718E-001, 2.50170419225469E-001),(-2.52607309492305E-001, 1.21318372432143E-001),(-1.28175049321726E-001, 1.80764379911125E-003),
( 4.98868824448437E-001, 1.31233477266505E-001),( 5.03358151763678E-003,-3.68688462534919E-001),( 1.29655734635890E-002, 3.64668707596138E-001),
( 1.14120068727061E-001,-2.52603175118566E-001),(-2.47624863404781E-001,-1.21524301823229E-001),(-3.73784049879760E-001, 2.52250944729894E-001),
(-1.19530248688534E-001,-4.95302199851722E-001),(-3.09525548014790E-001, 1.88805992715061E-001),( 4.40008281264454E-001,-1.90102331805974E-001),
(-4.32610965101048E-001,-4.39730194862932E-001),(-4.35654181521386E-001, 4.32705800514668E-001),(-4.38130201306194E-001, 6.63307772483677E-002),
( 1.91016715485603E-001,-3.10843382030726E-001),( 3.16779298475012E-001,-1.85507926624268E-001),(-6.44905299413949E-002,-6.05908299330622E-002),
(-1.91081997938454E-001, 1.85015608090907E-001),(-6.31072763353586E-002, 5.97983493935317E-002),(-3.13957682112232E-001,-3.08948922436684E-001),
( 6.72010269481689E-002,-4.42102895583958E-001),( 1.88557669753209E-001, 1.94748024223372E-001),( 1.87300925143063E-001, 3.07713891845197E-001),
( 4.43452182225883E-001,-3.14850484021008E-001),( 3.13073968980461E-001, 7.41561378818005E-002),(-3.15591655438766E-001, 6.01099305786193E-002),
( 4.41860174993053E-001,-4.34873239602894E-001),( 1.93047211738303E-001,-1.89385137753561E-001),(-1.90977088175714E-001,-5.82182123325765E-002),
(-4.37538115307689E-001,-1.89633420901373E-001),( 4.38117120182142E-001, 4.46383311180398E-001),(-6.60018129274249E-002, 1.81213899515569E-001),
(-1.92174372496083E-001, 6.07037444133312E-002),(-1.87313312897459E-001, 3.13038579421118E-001),(-1.89456258667633E-001,-3.07828947203234E-001),
( 3.13500677933917E-001,-4.33986469637603E-001),( 5.84728266112507E-002, 1.80739944567904E-001),(-4.78193643502891E-002,-4.35935723595321E-001),
(-3.04650183999911E-001,-4.38885199138895E-001),( 3.13857560977340E-001, 3.14515651669353E-001),(-6.60455483011902E-002,-1.87202933710069E-001),
( 5.79503246117383E-002,-6.51383646763861E-002),(-4.40938861109316E-001, 3.19035466993228E-001),(-6.96152173914015E-002,-3.05540300905705E-001),
(-1.82473727967590E-001,-4.33565215673298E-001),( 3.10902735218406E-001, 1.88500210177153E-001),(-4.57502088975161E-002, 4.23882060917094E-001),
( 4.39586111810058E-001, 1.97327216854319E-001),( 7.63248121365905E-002, 4.37611199915409E-001),(-3.13660959014669E-001,-6.07987784314901E-002),
( 3.20608273381367E-001,-5.58156110346317E-002),(-4.29722531465814E-001,-3.18481408059597E-001),( 3.16408896818757E-001, 4.42216942785308E-001),
(-3.06745011825115E-001, 3.17568494239822E-001),(-6.83462310116738E-002, 3.10073256259784E-001),(-4.32476226938889E-001, 1.89925173996016E-001),
(-4.36115940799937E-001,-6.54816690366715E-002),( 3.19297246169299E-001,-3.14025908242911E-001),( 4.44896155968309E-001,-6.36873226612806E-002),
( 1.86892414698377E-001,-4.32009935611859E-001),(-1.81040402734652E-001, 4.35273013310507E-001),( 4.37925621634349E-001, 3.18264617118985E-001),
( 5.91022609733045E-002,-1.88571820268408E-001),( 5.55755642708391E-002, 6.29763710312545E-002),(-1.84157223207876E-001,-1.79246553452686E-001),
( 4.41257830010727E-001, 7.18846714589745E-002),( 1.95063559571281E-001, 4.40691678086296E-001),(-3.07253559352830E-001, 4.43008849862963E-001),
( 1.79886227706447E-001, 5.75997207779437E-002),( 1.94736521691084E-001,-6.14163458812982E-002),(-3.09896851424128E-001,-1.82056121062487E-001),
( 6.91837344784290E-002, 3.09560892172158E-001),( 4.52577746473253E-002,-3.04193575866520E-001),( 3.11917026760057E-001, 1.02431732229888E-002),
(-5.36297971848399E-002, 4.95128618786112E-001),( 2.49813402770087E-001, 6.76731260027737E-002),( 3.72571225743741E-001, 1.93481370108202E-001),
( 1.85678238281980E-001,-1.26331638079137E-001),( 6.40828262548894E-002, 1.30748189985752E-003),( 4.36702174600214E-001, 4.12235106341541E-003),
( 3.15336607163772E-001,-1.21236784849316E-001),( 2.51257146941498E-001, 3.18120759446174E-001),(-6.57626388128847E-002,-1.26021655276418E-001),
( 1.22766121756285E-001, 1.83643880765885E-001),(-2.45742950122804E-001, 4.40797011833638E-001),(-2.44017844786868E-001,-4.35498473234475E-001),
( 1.17695052642375E-001, 5.02392281778157E-002),(-1.29576715873554E-001, 1.86295438790694E-001),(-3.76340202754364E-001,-1.84496115893126E-001),
( 3.18276957841590E-001, 2.51122389687225E-001),( 5.32454380299896E-002, 2.47820582473651E-001),( 1.86847685370594E-001, 1.33232297841460E-001),
(-3.15863016759977E-001,-3.42029612511396E-004),(-1.75076584098861E-001,-3.73810462420806E-001),(-4.37821222702041E-001, 1.27250389428809E-001),
(-4.93063640082255E-001,-3.11546971090138E-001),(-1.91268696449697E-001, 1.24962254194543E-001),(-3.72851056745276E-001,-4.43872232688591E-001),
(-2.50484219053760E-001,-6.18217026349157E-002),(-1.92843294702470E-001,-2.41135669173673E-001),( 4.34010965749621E-001, 3.82432379759848E-001),
(-6.94468885194510E-002, 2.41467612097040E-001),(-3.73457109555602E-001, 4.32889789342880E-001),( 3.78782651154324E-001,-1.82761393021792E-001),
(-4.36444953782484E-001,-2.52508451463655E-001),(-3.04682401241735E-001,-3.70263978373259E-001),(-2.53323326352984E-001,-3.04808419663459E-001),
( 2.49219795223326E-001, 1.93058942910284E-001),(-2.04050866886973E-003, 1.86108046909794E-001),( 2.55699847592041E-001,-1.86478511895984E-001),
( 1.89450182719156E-001,-3.71534469304606E-001),(-1.07458565616980E-001, 4.41511970013380E-001),( 3.16240912070498E-001,-4.96329434681684E-001),
(-4.33302358025685E-001, 4.94004513369873E-001),(-3.79899679683149E-003,-6.83916846755892E-002),(-3.14809393603355E-001, 3.82332040229812E-001),
(-3.14722829032689E-001, 1.22661199420691E-001),(-6.90734493546188E-002,-1.29561731591821E-003),(-4.95817770250142E-001, 1.92020796472207E-001),
(-4.98368611326441E-001, 4.38694969750941E-001),(-4.42166991299018E-001,-4.91944211535156E-003),(-3.11335591832176E-001, 2.52238800516352E-001),
( 2.55727905081585E-001,-3.12808453571051E-001),( 3.16617413423956E-001,-2.50491611659527E-001),( 4.38332914141938E-001,-1.23795341933146E-001),
( 4.40053731203079E-001,-2.52548285759986E-001),(-4.36543334741145E-001, 2.53825508058071E-001),(-1.29966210573912E-001,-3.16565475426614E-001),
(-4.97398554347456E-001,-4.35219315811992E-001),( 1.26354871317744E-001,-4.36227186582983E-001),( 1.06537909945473E-001,-3.13449601642788E-001),
(-3.81380744278431E-001, 3.11025695409626E-001),(-1.89742283895612E-001, 2.53740051994100E-001),( 3.10894462978467E-001, 3.73634238960221E-001),
( 3.81453552050516E-001,-5.28482820373029E-002),(-3.78852810710669E-001, 6.18139940779656E-002),(-3.76495320349932E-001,-6.08668720815331E-002),
( 1.89878572011367E-001, 3.78233763389289E-001),( 1.74741187365726E-001,-2.47294372646138E-001),( 2.48132429784164E-001,-4.34447301086038E-001),
( 1.81470185052604E-002, 4.25062782596797E-001),(-2.51219814643264E-001, 1.81758673395962E-001),(-1.89689006423578E-001, 3.76791028305888E-001),
(-4.96382902842015E-001,-1.88706549815834E-001),( 1.22306024190038E-001,-7.55089772865176E-002),( 3.76592978369445E-001, 4.38819240778685E-001),
( 1.30600052652881E-001,-1.95398816373199E-001),( 1.88869072357193E-001,-1.82001036591828E-003),(-1.86018824344501E-001,-1.20654403930530E-001),
( 3.79828309873119E-001,-4.34065130539239E-001),( 2.57618158124387E-001,-5.50880844239146E-002),( 3.82634545210749E-001,-3.11622038250789E-001),
(-6.32167654111982E-003,-1.88914094353095E-001),(-3.08210378047079E-001,-1.21480969712138E-001),( 4.97827491723001E-001, 3.16290535731241E-001),
( 6.26614000648260E-002,-1.28096988890320E-001),( 4.39004362560809E-001, 1.35043022921309E-001),(-2.99326464766637E-001,-4.98121024109423E-001),
( 3.12989316880703E-001,-3.73532674741000E-001),(-6.50382863823325E-002, 1.18676493642852E-001),(-4.93868895340711E-001,-5.30470637604594E-002),
( 1.29431531531736E-001, 3.15622920403257E-001),(-1.24467945657671E-001,-1.85610357439145E-001),( 4.49052476324141E-001,-3.76396083505824E-001),
(-1.79746285779402E-001, 4.96116491733119E-001),(-2.45495845330879E-001, 3.12935682712123E-001),(-4.35449325712398E-001,-1.28657152177766E-001),
( 3.81093417527154E-001, 6.90842773765326E-002),( 7.53043894656003E-002, 4.98846911592409E-001),(-4.98172187944874E-001, 6.69290299993009E-002),
(-5.60770756565035E-002,-3.67131213191897E-001),( 7.04554279800505E-002, 3.79565669689328E-001),( 6.80160166230053E-002,-3.79799066577107E-001),
(-1.86315576545894E-001, 2.72710807621479E-003),(-1.23691026121378E-001,-4.37029811087996E-001),( 9.02890018187463E-003,-4.47460863273591E-001),
(-3.68532072985545E-001, 1.87863618368283E-001),( 4.39402589341626E-001,-4.92395695764572E-001),(-4.83017954975367E-002, 3.66375498007983E-001),
(-2.49744918197393E-001, 5.99046731367707E-002),(-1.29671054426581E-001, 3.09148623840883E-001),(-6.42425615806133E-002,-2.47688475530595E-001),
(-4.24619947327301E-001,-3.82113225525245E-001),( 2.70018517039716E-003, 3.06029022904113E-001),( 6.38243681751192E-002, 1.19987340876833E-001),
( 1.97176608024165E-001, 4.99619824346155E-001),( 4.38970233779401E-001, 2.57178048370406E-001),( 2.54276722669601E-001, 4.42992428783327E-001),
( 1.37319415109232E-001, 4.44891812978312E-001),(-3.14326512860134E-001,-2.39638590719551E-001),(-4.43448890000582E-001, 3.75642548315227E-001),
(-2.51028524711728E-001,-1.81572080357000E-001),(-1.19169401004910E-002,-3.05797718465328E-001),( 1.69679351383820E-001, 2.53496097633615E-001),
(-1.32946734782308E-001,-5.64352006185800E-002),(-1.27882908098400E-001, 6.42592848744244E-002),( 3.72102107852697E-001, 3.22381050558761E-001),
(-4.88624675199390E-003, 6.06781670358032E-002),( 3.10403149109334E-001, 1.31737782387063E-001),( 5.96651765517891E-002,-2.41312617668882E-001),
(-3.77550109056756E-001,-3.16934408387169E-001),( 1.48037334438413E-001,-2.90399322984740E-001),( 2.13516031391919E-001, 2.33319059247151E-001),
(-1.46264090901241E-001, 4.62615949567407E-001),(-1.55177811160684E-001, 3.45062487758696E-001),(-8.44211312942207E-002,-4.61839929688722E-001),
( 2.23186942050234E-001,-1.53216441627592E-001),( 2.18417898984626E-001, 3.67721561342478E-002),( 2.86410073749721E-001,-8.87829426210374E-002),
(-4.04076591134071E-001, 4.02262212242931E-001),(-3.48608785774559E-001,-2.81165929511190E-001),( 4.80582196498290E-001,-8.85952308308333E-002),
( 2.10561109939590E-001, 9.44842766039074E-002),( 2.14034308213741E-001,-2.72426222916693E-001),( 3.33343870006502E-002,-4.10031195497140E-001),
( 1.59708566265181E-001, 9.81774609535933E-002),( 4.10946003859863E-001,-4.02474074391648E-001),( 2.22319904481992E-001, 2.82229223987088E-001),
(-4.65362476650626E-001, 3.21354051120579E-002),( 4.68090547947213E-001,-2.56987561006099E-002),( 4.68392922542989E-001, 3.65947810932994E-002),
( 2.14159318013117E-001, 3.42567916028202E-001),(-4.71832304727286E-001,-9.14939530193806E-002),(-3.54354251176119E-002, 2.82870010705665E-001),
( 4.69549702014774E-001,-1.58866455312818E-001),(-3.23236936237663E-002,-2.93825450353324E-002),( 2.22551593091339E-001,-3.39298656210303E-001),
(-4.68234148109332E-001, 4.69142970163375E-001),( 3.48348348634318E-001, 4.71105671953410E-001),(-2.80851835617796E-001, 2.21182191744447E-001),
(-1.14681685809046E-002,-4.08877174369991E-001),( 2.93970829807222E-002, 1.49636450689286E-001),(-1.58647224074230E-001, 1.55241523403674E-001),
(-2.22649279516190E-001,-2.72918378468603E-001),( 3.45978660043329E-001, 4.36345089692623E-002),(-2.23056691931561E-001,-2.94827963225544E-002),
(-4.03839528793469E-001, 4.63355904445052E-001),(-1.55889693414792E-001,-2.81903748866171E-001),( 3.22635255288333E-002,-9.87387199420482E-002),
(-3.40696829371154E-001,-1.50377059122548E-001),(-3.51078096544370E-001, 3.03504376206547E-002),(-2.76650128187612E-001,-4.07125444849953E-001),
( 2.76996789267287E-001, 1.60529475426301E-001),( 1.55962540535256E-001,-4.43662893958390E-002),(-2.83040857873857E-001, 8.65907969418913E-002),
( 9.48132572229952E-002,-4.23895241692662E-002),(-3.42782381689176E-001, 2.88243190851063E-001),( 4.11237999796867E-001,-3.46798198530451E-001),
( 2.16575930360705E-001,-2.26352001540363E-001),(-3.45104624517262E-001, 3.36284340592101E-001),( 2.79518018942326E-001,-4.04786378378049E-001),
( 2.83843573415652E-001,-2.18355629825965E-001),( 1.63112212205306E-001, 3.42811171663925E-001),(-4.11446962738410E-001, 3.27014913782477E-002),
(-2.84416645066813E-001,-2.73580449167639E-001),( 2.79357815859839E-001, 1.01362326182425E-001),( 2.84870326984674E-001, 4.13761605042964E-001),
(-1.01027930388227E-001,-2.77481191558763E-001),( 3.50348945474252E-001,-2.17580530792475E-001),(-2.04403278650716E-001,-4.69312161440030E-001),
(-4.00793047854677E-001, 2.18411120818928E-001),(-2.22630515927449E-001,-3.35457879118621E-001),(-8.65129455924034E-002,-4.14536026073620E-001),
( 4.71603983081877E-001,-2.20232346095145E-001),(-9.75911738350988E-002, 1.50461841840297E-001),(-3.35519738961011E-001,-4.71164722926915E-001),
(-4.60904276464135E-001,-4.06620559748262E-001),(-4.67469034250826E-001, 1.60098418127745E-001),( 2.79798757284880E-001,-1.51119157671928E-001),
(-3.47281042952091E-001, 9.27073820494116E-002),( 4.51854669954628E-002, 4.66364076128230E-001),(-4.69990086043254E-001, 9.88383912481368E-002),
( 2.18807329889387E-001,-4.02058628853411E-001),(-7.93804409913719E-002, 3.95899582188577E-001),( 3.46868554130197E-001,-1.52480706572533E-001),
(-2.82353065442294E-001,-3.08177403640002E-002),( 4.06550602521747E-001, 2.89405878633261E-001),(-4.69644323689863E-001, 2.85939675988630E-001),
(-1.61888341652229E-001, 2.19828143483028E-001),(-3.39990757871419E-001,-4.14198803016916E-001),(-4.02810803614557E-001,-4.75067368242890E-001),
(-2.20860572531819E-001, 3.47901946865022E-001),( 2.87988430587575E-001,-2.85318522946909E-001),(-2.19012894900516E-001, 2.17497232602909E-001),
( 4.06247591599822E-001, 1.65513538522646E-001),( 3.49239183124155E-002,-2.89568868465722E-002),(-9.13464163895697E-002,-3.42683045193553E-001),
(-3.39965792372823E-002, 2.47322365175933E-002),(-4.60137923480943E-001,-4.72248644102365E-001),( 2.85670735640451E-001,-4.66182656586170E-001),
(-9.70676699653268E-002, 3.15451801288873E-002),( 4.70817130059004E-001, 4.73463159287348E-001),( 9.52269600238651E-002,-1.67615367565304E-001),
( 3.50473624886945E-001,-2.84402549732477E-001),( 4.03438206994906E-001,-2.17507531633601E-001),( 9.28696494083852E-002, 8.85727494023740E-002),
( 4.00982100982219E-002,-4.77207373362035E-001),( 1.45719380117953E-001,-3.33145818207413E-001),(-3.73313082382083E-002,-9.51319530140609E-002),
( 4.70746161649004E-001, 2.84885739674792E-001),( 4.68577783321962E-001, 1.64718664251268E-001),(-3.44017583876848E-001,-2.10459624417126E-001),
(-2.54358099773526E-002,-4.73266951972619E-001),( 1.61830490222201E-001,-9.05621647834778E-002),(-4.56198145635426E-001,-3.52436124347150E-001),
(-1.00082619115710E-001,-8.28494781162590E-002),(-2.13617668719962E-001,-4.04678049497306E-001),(-4.66233808314428E-001, 2.24311053752899E-001),
( 4.05464911134914E-001, 3.49746697349474E-001),( 2.89093656931073E-001,-2.68016927875578E-002),(-3.61979079898447E-002, 2.13027789723128E-001),
(-2.84568704664707E-001, 3.03236092440784E-002),(-4.08712972188369E-001, 3.47108844667673E-001),( 2.84353842725977E-001, 2.22517111571506E-001),
( 3.44595222501084E-001, 1.06879575643688E-001),(-1.00011643720791E-001,-1.51423973264173E-001),(-8.83780769072473E-002, 3.47571092657745E-001),
( 3.49497834686190E-001, 2.86175950197503E-001),(-2.60821925476193E-002, 4.62477329187095E-001),(-4.67223598854616E-001,-1.55768796568736E-001),
(-2.18419290147722E-001, 4.09316226840019E-001),( 9.16194156743586E-002, 1.54571153922007E-001),( 3.46600992837921E-001,-2.31888452544808E-002),
(-4.67648690100759E-001,-2.21390370978043E-001),( 1.58012379892170E-001, 4.08934517530724E-001),( 1.64847616106272E-001,-4.67235367279500E-001),
( 8.01902953535319E-002,-2.79219266725704E-001),( 3.42962617287412E-001, 1.60552856745198E-001),(-1.58156852936372E-001, 3.46648348495364E-002),
(-4.03521475614980E-001,-2.82463688403368E-001),(-9.58951341453940E-002,-2.19582299469039E-001),( 3.42840445460752E-001, 4.08311548642814E-001),
(-9.90785881876946E-002, 2.79547828482464E-001),( 1.54039047192782E-001, 2.26365772541612E-002),( 4.70266502816230E-001, 4.09124697791413E-001),
(-1.53194985352457E-001,-4.69976488966495E-001),(-3.37410222971812E-001, 1.57918825978413E-001),( 4.63277602335438E-001, 3.51598944049329E-001),
(-2.17953972285613E-001,-2.07487472100183E-001),(-3.43503087759018E-001,-3.19139284547418E-002),( 2.77591575868428E-002, 3.09354143682867E-002),
( 4.71840318990871E-001,-2.84643902909011E-001),(-3.43656163662672E-001,-3.42790758004412E-001),( 8.41408155392856E-002, 2.15145579539239E-001),
(-2.21486441092566E-001, 9.13383422885090E-002),(-3.40853282483295E-001, 2.20840418478474E-001),(-2.74899812648073E-001, 3.44361987197772E-001),
( 2.83547129249200E-001, 4.07553247641772E-002),( 2.19975725980476E-001, 1.59775238018483E-001),(-1.59161796327680E-001,-8.81953737698496E-002),
(-3.54260464664549E-002,-1.59221748122945E-001),( 1.50716073578224E-001, 2.13486770633608E-001),( 3.41779530979693E-001,-4.64483246672899E-001),
( 4.07748047495261E-001, 3.74520677141845E-002),( 2.96335557941347E-002, 2.12120621465147E-001),( 1.56692385440692E-001,-1.60396588966250E-001),
( 2.85807195818052E-001, 2.79864664655179E-001),(-1.01867433637381E-001,-2.96483603306115E-002),( 4.07922811340541E-001, 2.24916969891638E-001),
(-1.52013980550692E-001,-1.52654313482344E-001),(-1.53642582939938E-001, 4.01448691729456E-001),(-4.05352889560163E-001,-9.61658412124962E-002),
( 9.26432835403830E-002,-2.15256098425016E-001),( 4.06373207457364E-001,-4.67195651959628E-001),( 2.84937228076160E-001, 4.71645963378251E-001),
(-3.04388278163970E-002, 1.55043235048652E-001),(-2.80390830943361E-001,-1.52788842562586E-001),(-2.84496996318922E-001, 1.55364317819476E-001),
(-2.18162636738271E-001,-1.52110038558021E-001),( 4.09522318281233E-001,-8.39493111707270E-002),( 9.89426376763731E-002, 3.43231795355678E-001),
( 3.08748111128807E-002, 9.56190677825362E-002),(-2.73193475557491E-001,-3.44246870372444E-001),( 7.45273416396231E-002,-3.38160391198471E-001),
( 4.74731767550111E-001,-4.66270856792107E-001),(-4.05650795204565E-001,-2.16339990729466E-001),( 3.44443914480507E-001,-9.17317362036556E-002),
( 1.01419928949326E-001,-4.04060921398923E-001),( 4.14590777130798E-001,-2.84938629018143E-001),( 2.40504273679107E-002,-2.21696569584310E-001),
(-3.32155246986076E-001, 4.77306447457522E-001),( 1.59954620990902E-001,-4.00939734652639E-001),( 4.74559869850054E-001,-3.45114010851830E-001),
( 4.05443743802607E-001, 4.73640010925010E-001),( 3.46157045802102E-001,-4.04914279235527E-001),( 3.46219687722623E-001,-3.47397366538644E-001),
( 4.67702100286260E-001, 2.27080445969477E-001),(-4.11837935913354E-001,-3.26388594694436E-002),(-4.02589727891609E-001, 9.75492442958057E-002),
( 1.11422301270068E-001, 4.11814543418586E-001),(-4.02589003555477E-001, 1.61806212272495E-001),(-4.59991688141599E-001,-2.86550829885528E-001),
(-2.68516340991482E-001,-4.67904753750190E-001),( 3.00422986038029E-002,-1.59720682073385E-001),(-4.71450723474845E-001, 4.07683496130630E-001),
( 4.11412879824638E-001,-1.58056777436286E-001),(-3.42940638773143E-001,-9.29442429915071E-002),( 2.26522433338687E-001,-8.70828663464636E-002),
( 2.25332708330825E-001,-4.69693206017837E-001),( 1.03845254285261E-001,-4.71991016296670E-001),(-2.85176469013095E-001, 2.82904312713072E-001),
( 8.47290400415659E-002,-9.44492707494647E-002),(-3.18639182951301E-002, 9.34850138146430E-002),(-1.52815155219287E-001,-4.06663690926507E-001),
( 3.41443833196536E-001, 2.19151252647862E-001),( 2.25611362839118E-001, 4.14805689593777E-001),(-2.20838756999001E-001, 2.96389679424465E-002),
(-2.78280657483265E-001, 4.12156968144700E-001),(-2.12787490570918E-001, 4.65784998144955E-001),(-1.62484361557290E-001, 8.86841756291688E-002),
(-2.80678930925205E-001,-2.11467575049028E-001),( 2.24162487080321E-001,-2.63086073100567E-002),( 4.11980065051466E-001, 1.01755808340386E-001),
(-1.55433699721471E-001,-2.11020513204858E-001),(-1.39472712762654E-002, 3.98598265601322E-001),(-1.58221940742806E-001, 2.80491678277031E-001),
( 1.02683483855799E-001, 2.82865897053853E-001),(-4.10298365168274E-001,-1.58887814963236E-001),(-2.72763871122152E-001, 4.69899257877842E-001),
(-3.99490595329553E-001,-4.13303155219182E-001),(-2.18447738559917E-001, 1.54763232450932E-001),(-2.97197005711496E-002, 3.29637149814516E-001),
( 2.87701364839450E-001,-3.39890536153689E-001),(-9.54299566801638E-002, 9.22573010902852E-002),( 4.69802689040080E-001, 1.02806929964572E-001),
( 4.09875343786553E-001, 4.15626941481605E-001),( 2.76371028739959E-001, 3.49178047152236E-001),(-1.59792903345078E-001,-2.72220252081752E-002),
(-4.74459679331631E-001, 3.45337239326909E-001),( 1.05260163079947E-001, 4.69071009662002E-001),( 3.39743365766481E-001, 3.47644758876413E-001),
(-4.02468200540170E-001,-3.47905899863690E-001),(-1.05744979111478E-001, 2.19171087723225E-001),(-4.17566919699311E-001, 2.88031390402466E-001),
( 2.50359594356269E-002, 2.74167943280190E-001),(-7.01714307069779E-002, 4.59699777886272E-001),(-2.17975361738354E-001,-8.97456402890384E-002),
( 4.78873032610864E-001,-4.00825888616964E-001),(-3.81921546068043E-002,-2.76906494051218E-001),( 1.49024891667068E-001, 1.54364212648943E-001),
(-3.59402846079320E-002,-2.20017550047487E-001),( 3.53037246968597E-002, 3.31585662672296E-001),(-3.89501322060824E-002,-3.32955271238461E-001),
( 2.67473608255386E-002,-2.66254485584796E-001),( 1.82490688748658E-002,-3.31232874421403E-001),(-2.80288858106360E-001,-8.52102816570550E-002),
( 1.51043476536870E-001, 2.85433481214568E-001),(-2.18760388670489E-001, 2.80077951960266E-001),( 2.24555717548356E-001, 4.69023748766631E-001),
( 9.42734698764980E-002, 2.21359666902572E-002),( 1.65235575754195E-001, 4.76701361592859E-001),(-3.49687807727605E-001, 3.98246467579156E-001),
( 4.06320289941505E-001,-2.32744466047734E-002));

PROCEDURE writeConstantDarts(maxIdx:longint);
FUNCTION initDarts(seed:longint; stopOnTol:double; i0,i1:longint):double;
IMPLEMENTATION
VAR delta:array[0..1015,0..1] of double;
    base :array[0..1015,0..1] of double;

PROCEDURE writeConstantDarts(maxIdx:longint);
  VAR i:longint;
  begin
    write('CONST darts_delta:array[0..',maxIdx,',0..1] of single=(');
    for i:=0 to maxIdx do begin
      base[i,0]:=delta[i,0];
      base[i,1]:=delta[i,1];
      if ((i mod 3)=0) then writeln;
      write('(',delta[i,0],',',delta[i,1],'),');
    end;
    writeln(');');
  end;

FUNCTION initDarts(seed:longint; stopOnTol:double; i0,i1:longint):double;
  FUNCTION pDist(CONST x0,y0,x1,y1:double):double; inline;
    VAR dx,dy:double;
    begin
      dx:=x1-x0; if dx<0 then dx:=-dx; if dx>0.5 then dx:=1-dx;
      dy:=y1-y0; if dy<0 then dy:=-dy; if dy>0.5 then dy:=1-dy;
      result:=dx*dx+dy*dy;
    end;

  VAR i,j:longint;
      tol:double=1;
  begin
    randseed:=seed;
    for i:=0 to i0-1 do begin
      delta[i,0]:=base[i,0];
      delta[i,1]:=base[i,1];
    end;
    for i:=i0 to i1 do begin
      repeat
        delta[i,0]:=random-0.5;
        delta[i,1]:=random-0.5;
        j:=0;
        while (j<i) and (pDist(delta[i,0],delta[i,1],delta[j,0],delta[j,1])>tol) do inc(j);
        tol:=tol*0.99999;
      until (j>=i) or (tol<stopOnTol);
      if tol<stopOnTol then exit(0);
    end;
    result:=tol;
  end;

INITIALIZATION
  base[0,0]:=0;
  base[0,1]:=0;

end.
