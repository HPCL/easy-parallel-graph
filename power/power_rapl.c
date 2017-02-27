#include "power_rapl.h"

void power_rapl_init(power_rapl_t* ps) {
    int cid=-1, i, code, retval, enum_retval;
    ps->EventSet = PAPI_NULL;
    const PAPI_component_info_t *cmpinfo = NULL;
    char event_name[BUFSIZ];
    int rapl_cid;

    ps->num_events = 0;


    /* PAPI Initialization */
    retval = PAPI_library_init( PAPI_VER_CURRENT );
    if ( retval != PAPI_VER_CURRENT ) {
        fprintf(stderr,"PAPI_library_init failed\n");
        exit(1);
    }

    ps->numcmp = PAPI_num_components();

    for(cid = 0; cid < ps->numcmp; cid++) {

        if ( (cmpinfo = PAPI_get_component_info(cid)) == NULL) {
            fprintf(stderr,"PAPI_get_component_info failed\n");
            exit(1);
        }

        if (strstr(cmpinfo->name,"rapl")) {
            rapl_cid=cid;
            printf("Found rapl component at cid %d\n", rapl_cid);

            if (cmpinfo->disabled) {
                fprintf(stderr,"No rapl events found: %s\n",
                        cmpinfo->disabled_reason);
                exit(1);
            }
            break;
        }
    }

    /* Component not found */
    if (cid==ps->numcmp) {
        fprintf(stderr,"No rapl component found\n");
        exit(1);
    }

    /* Find Events */
    code = PAPI_NATIVE_MASK;

    enum_retval = PAPI_enum_cmp_event( &code, PAPI_ENUM_FIRST, cid );

    while ( enum_retval == PAPI_OK ) {

        retval = PAPI_event_code_to_name( code, event_name );
        if ( retval != PAPI_OK ) {
            printf("Error translating %#x\n",code);
            exit(1);
        }

        printf("Found: %s\n", event_name);
        strncpy(ps->events[ps->num_events], event_name, BUFSIZ);
        sprintf(ps->filenames[ps->num_events], "results.%s", event_name);
        ps->num_events++;

        if (ps->num_events == MAX_RAPL_EVENTS) {
            printf("Too many events! %d\n",ps->num_events);
            exit(1);
        }

        enum_retval = PAPI_enum_cmp_event( &code, PAPI_ENUM_EVENTS, cid );
    }

    if (ps->num_events==0) {
        printf("Error!  No RAPL events found!\n");
        exit(1);
    }

    /* Create EventSet */
    retval = PAPI_create_eventset( &(ps->EventSet) );
    if (retval != PAPI_OK) {
        fprintf(stderr,"Error creating eventset!\n");
    }

    for(i = 0; i < ps->num_events; i++) {
        retval = PAPI_add_named_event( ps->EventSet, ps->events[i] );
        if (retval != PAPI_OK) {
            fprintf(stderr,"Error adding event %s\n", ps->events[i]);
        }
    }
    ps->start_time=PAPI_get_real_nsec();
}

void power_rapl_start(power_rapl_t* ps) {
    ps->before_time = PAPI_get_real_nsec();
    int retval = PAPI_start(ps->EventSet);
    if (retval != PAPI_OK) {
        fprintf(stderr,"PAPI_start() failed\n");
        exit(1);
    }
}

void power_rapl_end(power_rapl_t* ps) {
    /* Stop Counting */
    long long after_time=PAPI_get_real_nsec();
    int retval = PAPI_stop( ps->EventSet, ps->values);
    if (retval != PAPI_OK) {
        fprintf(stderr, "PAPI_stop() failed\n");
    }

    ps->total_time = ((double)(after_time - ps->start_time))/1.0e9;
    ps->elapsed_time = ((double)(after_time - ps->before_time))/1.0e9;
}

/* Units for Energy are nJ. You can check others with
 * sudo papi_naitve_avail -i rapl
 */
void power_rapl_print(power_rapl_t* ps) {
    int i;
    for(i = 0; i < ps->num_events; i++) {
        if (strncmp(ps->events[i], "rapl:::PACKAGE_ENERGY:PACKAGE", 29) == 0) {
            printf("%.4f s %.4f (* Total Energy for %s *)\n",
                    ps->elapsed_time,
                    ((double)ps->values[i]/1.0e9),
                    ps->events[i]);
        }
        printf("%.4f s %.4f (* Average Power for %s *)\n",
                ps->elapsed_time,
                ((double)ps->values[i]/1.0e9)/(double)ps->elapsed_time,
                ps->events[i]);
    }
}

