#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "../../ppport.h"

/* These were stolen from http://cpansearch.perl.org/src/AMS/Storable-2.30/Storable.xs */
#ifndef HvRITER_set
#  define HvRITER_set(hv,r) (HvRITER(hv) = r)
#endif

#ifndef HvRITER_get
#  define HvRITER_get HvRITER
#endif
/* end theft */

MODULE = Hash::StoredIterator PACKAGE = Hash::StoredIterator

I32 hash_get_iterator( hv )
        HV *hv
    CODE:
        RETVAL = HvRITER_get(hv);
    OUTPUT:
        RETVAL

void hash_set_iterator( hv, i )
        HV *hv
        I32 i
    CODE:
        HvRITER_set(hv, i);

void hash_init_iterator( hv )
        HV *hv
    CODE:
        hv_iterinit(hv);

