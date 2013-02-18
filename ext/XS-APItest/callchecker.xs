MODULE = XS::APItest		PACKAGE = XS::APItest::callchecker

UV
callchecker_address()
    CODE:
	RETVAL = PTR2UV(my_callchecker);
    OUTPUT:
	RETVAL

UV
callchecker_sv_address()
    CODE:
	RETVAL = PTR2UV(my_callchecker_sv);
    OUTPUT:
	RETVAL

void
setcallchecker(cv)
	CV * cv
    CODE:
	SV * ckobj = (SV *)cv;
	cv_set_call_checker(cv, my_callchecker, ckobj);

void
setcallchecker_sv(cv)
	CV * cv
    CODE:
	SV * ckobj = (SV *)cv;
	cv_set_call_checker_sv(cv, my_callchecker_sv, ckobj);

UV
getcallchecker(cv)
	CV * cv
    CODE:
	Perl_call_checker ckfun;
	SV *ckobj;
	cv_get_call_checker(cv, &ckfun, &ckobj);
	RETVAL = PTR2UV(ckfun);
    OUTPUT:
	RETVAL

UV
getcallchecker_sv(cv)
	CV * cv
    CODE:
	Perl_call_checker_sv ckfun;
	SV *ckobj;
	cv_get_call_checker_sv(cv, &ckfun, &ckobj);
	RETVAL = PTR2UV(ckfun);
    OUTPUT:
	RETVAL
