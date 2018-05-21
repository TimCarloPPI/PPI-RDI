000100180419**FREE
000101180419ctl-opt dftactgrp(*no) actgrp('CARLO') decedit('0.')
000102180419        bnddir('YAJL') option(*srcstmt: *nodebugio: *noshowcpy);
000103180419
000104180420/include YAJL/QRPGLESRC,YAJL_H
000105180419
000106180419dcl-c UPPER const('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
000107180419dcl-c lower const('abcdefghijklmnopqrstuvwxyz');
000108180419
000112180419// data template in reponse template
000113180419dcl-ds data_t qualified template;
000114180419   itemnum char(15) inz('');
000115180420   cost zoned(15: 8) inz(0);
000117180419end-ds;
000118180419
000119180419// response template
000120180419dcl-ds itemcost_t qualified template;
000121180419   success ind inz(*on);
000122180419   errorMsg varchar(500) inz('');
000123180419   data likeds(data_t) inz(*likeds);
000124180419end-ds;
000125180419
000127180419// the response data structure
000128180419dcl-ds itemcost likeds(itemcost_t) inz(*likeds);
000129180419
000130180423dcl-s itemnum like(data_t.itemnum) inz('');
000132180419dcl-s errmsg varchar(500) inz('');
000133180419dcl-s method varchar(10);
000134180419
000135180424clear itemcost;
000136180424
000137180419exec SQL
000138180419   set option naming=*sys, commit=*none;
000139180419
000140180419if getInput( method: itemnum: errmsg ) = *off;
000141180419   itemcost.success = *off;
000142180419   itemcost.errorMsg = errmsg;
000145180419   sendResponse(itemcost);
000146180419   return;
000147180419endif;
000148180419
000151180419Select;
000152180420  when method = 'GET' and itemnum <> *blanks;
000153180419    loadDbRecord(itemnum: itemcost);
000154180419    sendResponse(itemcost);
000155180419ENDSL;
000156180423
000157180423return;
000158180419
000159180419// ------------------------------------------------------------------------
000160180419//   getInput():  Retrieve the basic HTTP input for this call
000161180419//
000162180419//      method = (output) HTTP method used (GET, POST, DELETE, PUT)
000163180419//      custid = (output) customer id, or 0 if none provided
000164180419//      errmsg = (output) error message that occurred (if any)
000165180419//
000166180419//   Returns *ON if successful, *OFF otherwise
000167180419// ------------------------------------------------------------------------
000168180419
000169180419dcl-proc getInput;
000170180419
000171180419   dcl-pi *n ind;
000172180419      method varchar(10);
000173180420      inputitemnum like(data_t.itemnum);
000174180419      errmsg varchar(500);
000175180419   end-pi;
000176180419
000177180419   dcl-pr getenv pointer extproc(*dclcase);
000178180419      var pointer value options(*string);
000179180419   end-pr;
000180180419
000181180423   dcl-c REQUIRED_PART const('/rest/itmcst/');
000182180419
000183180419   dcl-s env pointer;
000184180419   dcl-s pos int(10);
000185180420   dcl-s urlitemnum varchar(50);
000186180419   dcl-s url varchar(1000);
000187180419
000188180419   errMsg = '';
000189180419   method = 'GET';
000190180419   url    = '';
000191180419
000192180419   // ------------------------------------------------------
000193180419   // Retrieve the HTTP method.
000194180419   //  -  Default to GET if not provided
000195180419   // ------------------------------------------------------
000196180419
000197180419   env = getenv('REQUEST_METHOD');
000198180419   if env <> *null;
000199180419      method = %xlate(lower: UPPER: %str(env));
000200180419   endif;
000201180419
000202180419   // ------------------------------------------------------
000203180419   //  Retrieve the URL
000204180419   //   - Should always be provided!
000205180419   // ------------------------------------------------------
000206180419
000207180419   env = getenv('REQUEST_URI');
000208180419   if env = *null;
000209180419      errMsg = 'Unable to retrieve URL';
000210180419      return *off;
000211180419   else;
000212180419      url = %xlate(UPPER: lower: %str(env));
000213180419   endif;
000214180419
000215180419   // ------------------------------------------------------
000216180420   //   Extract the Item Number from the URL.
000217180420   //    - if not provided, set to BLANK
000218180419   //    - should always be provided for PUT/POST/DELETE
000219180419   // ------------------------------------------------------
000220180419
000221180419   monitor;
000222180419      pos = %scan(REQUIRED_PART:url) + %len(REQUIRED_PART);
000223180420      urlitemnum = %subst(url: pos);
000224180424      inputitemnum = %xlate(lower: UPPER: %trim(urlitemnum));
000225180419   on-error;
000226180420      inputitemnum = *blank;
000227180419   endmon;
000228180419
000229180420   if inputitemnum = *blank;
000230180420      errMsg = 'You must supply an Item Number!';
000231180419      return *off;
000232180419   endif;
000233180419
000234180419   return *on;
000235180419
000236180419end-proc;
000237180419
000238180419// ------------------------------------------------------------------------
000239180419//   loadDbRecord():  Load customer database record
000240180419//
000241180423//   itemnum  = (input)      Item to retrieve
000243180420//   itemcost = (output)     data structure to be sent as response
000244180419//
000245180419//   returns *on if record loaded, *off otherwise
000246180419// ------------------------------------------------------------------------
000247180419
000248180419dcl-proc loadDbRecord;
000249180419
000250180419   dcl-pi *n ind;
000251180420      lookupitemnum like(data_t.itemnum) const;
000252180420      returnds likeds(itemcost_t);
000253180419   end-pi;
000254180419
000255180420   dcl-s iaucdef zoned(15: 8) inz(0);
000256180420   dcl-s ibstdcs zoned(15: 8) inz(0);
000257180420   dcl-s ibcurcs zoned(15: 8) inz(0);
000258180420   dcl-s calculatedcost zoned(15: 8) inz(0);
000259180419
000260180419   exec SQL
000261180420     select cast(ucdef as Dec(15,8))
000262180420       into :iaucdef
000263180420       from amflibn/itemasa
000264180420      where itnbr = :lookupitemnum;
000265180419
000266180420   if %subst(sqlstt:1:2) <> '00' and %subst(sqlstt:1:2) <> '01';
000267180420      returnds.success = *off;
000268180423      returnds.errorMsg = lookupitemnum + 'Itemasa not found!';
000269180419      return *off;
000270180419   endif;
000271180419
000272180420   exec SQL
000273180420     select cast(stduc as Dec(15,8)), cast(curuc as Dec(15,8))
000274180420       into :ibstdcs, :ibcurcs
000275180420       from amflibn/itemasb
000276180420      where itnbr = :lookupitemnum;
000277180420
000278180420   if %subst(sqlstt:1:2) <> '00' and %subst(sqlstt:1:2) <> '01';
000279180420      returnds.success = *off;
000280180423      returnds.errorMsg = lookupitemnum + 'Itemasb not found!';
000281180420      return *off;
000282180420   endif;
000283180420
000284180420   // once all values have been successfully retrieved do work to return correct value
000285180420   // does not call BASEYR yet
000286180420
000287180420   calculatedcost = iaucdef;
000288180420   if ibstdcs > iaucdef;
000289180420     calculatedcost = ibstdcs;
000290180420   endif;
000291180420   if ibcurcs > iaucdef;
000292180420     calculatedcost = ibcurcs;
000293180420   endif;
000294180420
000295180423   returnds.success = *on;
000296180423   returnds.errormsg = ('');
000298180420   returnds.data.itemnum = lookupitemnum;
000299180420   returnds.data.cost = calculatedcost;
000300180419
000301180419   return *on;
000302180419
000303180419end-proc;
000304180419
000305180419// ------------------------------------------------------------------------
000306180419//  sendResponse():  Send the JSON response document
000307180419//
000308180423//    itemcost = (input) item cost information DS
000309180419//
000310180419//  returns *ON if successful, *OFF otherwise.
000311180419// ------------------------------------------------------------------------
000312180419
000313180419dcl-proc sendResponse;
000314180419
000315180419   dcl-pi *n ind;
000316180420      tosendds likeds(itemcost_t) const;
000317180419   end-pi;
000318180419
000319180419   dcl-s errMsg varchar(500) inz('');
000320180419
000321180419   yajl_genOpen(*on);
000322180419   yajl_beginObj();
000323180419
000324180420   yajl_addBool('success': tosendds.success);
000325180420   yajl_addChar('errorMsg': tosendds.errorMsg);
000326180419
000327180420   if tosendds.success = *on;
000328180419
000329180419      yajl_beginObj('data');
000330180419
000331180424      yajl_addChar('ItemNumber': %trim(tosendds.data.itemnum));
000332180424      yajl_addNum('ItemCost': %char(tosendds.data.cost));
000333180419
000334180419      yajl_endObj();
000335180419
000336180419   endif;
000337180419
000338180419   yajl_endObj();
000339180419
000340180420   if tosendds.success;
000341180419      yajl_writeStdout(200: errMsg);
000342180419   else;
000343180419      yajl_writeStdout(500: errMsg);
000344180419   endif;
000345180419
000346180419   yajl_genClose();
000347180419
000348180419   return (errMsg = '');
000349180419
000350180419end-proc;
