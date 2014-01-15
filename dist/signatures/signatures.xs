#define PERL_NO_GET_CONTEXT     /* we want efficiency */
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

/* vim:set ts=8 sts=4 noet: */

/* If the version of this in toke.c can be exported, we can use that */
PERL_STATIC_INLINE char *
parse_ident(pTHX_ char *ptr, const char * end, bool is_utf8) {
    for (;;) {
        if (is_utf8 && isIDFIRST_utf8((U8*)ptr)) {
            ptr = ptr + UTF8SKIP(ptr);
            while (isIDCONT_utf8((U8*)ptr))
                ptr += UTF8SKIP(ptr);
        }
        else if ( isWORDCHAR_A(*ptr) ) {
            do { ptr++; } while (isWORDCHAR_A(*ptr) && ptr < end);
        }
        else
            break;
    }
    return ptr;
}


STATIC OP * signatures_initsub(pTHX)
{
    AV * args = GvAV(PL_defgv);
    SV ** argsa = AvARRAY(args);
    int argc = av_len(args) + 1;
    int padc = SvIVX(cSVOPx_sv(PL_op));
    const int lasttype = SvTYPE(PAD_SVl(padc));
    const bool dogreedy = (argc >= padc && lasttype >= SVt_PVAV) ? TRUE : FALSE;
    int lastix = argc < padc ? argc : (dogreedy ? padc - 1 : padc);
    int i;

    /* Set up the savestack to clear the range */
    const UV payload = (UV)(
                            (1 << (OPpPADRANGE_COUNTSHIFT + SAVE_TIGHT_SHIFT))
                          | (padc << SAVE_TIGHT_SHIFT)
                          | SAVEt_CLEARPADRANGE);
    dSS_ADD;
    SS_ADD_UV(payload);
    SS_ADD_END(1);

    /* TODO: Optional warning if there are unslurped args,
       controlled by callee, not caller */

    /* Set all the simple scalars */
    for (i = 0; i < lastix; i++) {
        SV * sv = PAD_SVl(i + 1);
        sv_setsv(sv, argsa[i]);
        SvPADSTALE_off(sv);
    }

    /* Clear the stale flag on anything not initialized; we're considering it
       implicitly initialized to undef */
    for (i = lastix; i < padc; i++)
        SvPADSTALE_off(PAD_SVl(i + 1));

    /* Set the last, if it takes an array or hash and there's something to fill it */
    if (dogreedy) {
        assert(lasttype == SVt_PVAV || lasttype == SVt_PVHV);
        SV * sv = PAD_SVl(padc);
        SvPADSTALE_off(sv);
        if (lasttype == SVt_PVAV) {
            SV ** ary;
            AV * const av = MUTABLE_AV(sv);
            av_extend(av, argc - padc);
            AvMAX(av) = argc - padc;
            AvFILLp(av) = argc - padc;
            ary = AvARRAY(av);
            while (argc-- > lastix)
                ary[argc-lastix] = newSVsv(argsa[argc]);
        } else {
            HV * const hv = MUTABLE_HV(sv);
            if ((argc - padc) % 2 == 0)
                (void)hv_store_ent(hv, argsa[--argc], newSV(0), 0);
            while (argc > padc) {
                SV * const val = newSVsv(argsa[--argc]);
                (void)hv_store_ent(hv, argsa[--argc], val, 0);
            }
        }
    }

    return NORMAL;
}

MODULE = signatures            PACKAGE = signatures

SV *
parser(SV *proto)
    PPCODE:
        SV *sv = newSVsv(cSVOPx_sv((OP*)proto));
        AV * list = newAV();
        char * ptr;
        const char * end = SvEND(sv);
        int i;
        bool last_was_greedy = FALSE;
        const bool UTF = cBOOL(SvUTF8(sv));
        /* Two passes, optimizing for maintainability.
           Pass 1: Check if there are any word characters.  If there *aren't*,
                   this is a prototype.
        */
        ptr = SvPVX(sv);
        while (ptr < end) {
            if (isALNUM_lazy_if(ptr, UTF))
                break;
            else
                ptr += UTF ? UTF8SKIP(ptr) : 1;
        }
        if (ptr >= SvEND(sv)) {
            sv_free(sv);
            sv_free(MUTABLE_SV(list));
            (void)Perl_validate_proto(aTHX_ PL_subname, sv, ckWARN(WARN_ILLEGALPROTO));
            ST(0) = proto;
            XSRETURN(1);
        }
        /*
           Pass 2: Handle the signature
        */
        ptr = SvPVX(sv);
        do {
            char * start = NULL;
            while (isSPACE(*ptr)) ptr++;
            start = ptr;
            if (*ptr == ',')
                croak("Missing variable name in parameter list (consecutive commas)");
            if (!strchr("$@%",*ptr++)) {
                croak("Bad name in signature, starting at '%s'", start);
            }
            if (*start != '$') {
                if (last_was_greedy)
                    croak("Only the last parameter can be greedy (a hash or an array)");
                else
                    last_was_greedy = TRUE;
            }
            if (isIDFIRST_lazy_if(ptr, UTF)) {
                SV * varname;
                ptr = parse_ident(ptr, end, UTF);
                varname = newSVpvn_flags(start, (ptr-start), SVs_TEMP | SvUTF8(sv));
                for (i = 0; i <= AvFILLp(list); i++) {
                    if (sv_cmp_flags(varname, AvARRAY(list)[i], 0) == 0)
                        croak("%s was declared twice in the same signature", SvPVX(varname));
                }
                av_push(list, varname);
            } else {
                croak("Bad name in signature, starting at '%s'", start);
            }
            while (isSPACE(*ptr)) ptr++;
            if (*ptr != ',' && *ptr != '\0')
                croak("Only variable names, commas, and spaces are legal in signatures");
        } while (*ptr++);

        /* If we haven't croaked or returned, initialize the pad and return the op */
        SvIV_set(sv, AvFILLp(list) + 1);
        for (i = 0; i <= AvFILLp(list); i++) {
            SV * varname = AvARRAY(list)[i];
            const int pad_ix = pad_add_name_sv(varname, 0, NULL, NULL);
            switch (*SvPVX(varname)) {
                case '%': sv_upgrade(PAD_SVl(pad_ix), SVt_PVHV); break;
                case '@': sv_upgrade(PAD_SVl(pad_ix), SVt_PVAV); break;
                default: break;
            }
        }
        SVOP* op = (SVOP*)newSVOP(OP_SUBINIT, 0, sv);
        op->op_ppaddr = signatures_initsub;
        op_free((OP*)proto);
        ST(0) = (SV*)op;
        XSRETURN(1);
