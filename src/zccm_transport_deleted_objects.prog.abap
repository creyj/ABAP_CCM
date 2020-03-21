*&---------------------------------------------------------------------*
*& Report  ZCCM_TRANSPORT_DELETED_OBJECTS
*&
*&---------------------------------------------------------------------*
*& set object function to D in a transport object, if object does not
*& exist anymore.
*&---------------------------------------------------------------------*
REPORT zccm_transport_deleted_objects.

PARAMETERS: p_trkorr TYPE e070-trkorr OBLIGATORY.
PARAMETERS: p_devc type tadir-devclass OBLIGATORY.


CLASS lcl_app DEFINITION.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING
        iv_trkorr TYPE e070-trkorr
        iv_devc TYPE tadir-devclass.
    METHODS main.
  PRIVATE SECTION.
    CONSTANTS gc_deleted TYPE string VALUE 'D' ##NO_TEXT.

    DATA mv_trkorr TYPE e070-trkorr.
    DATA mv_devc TYPE tadir-devclass.
    METHODS insert_tadir IMPORTING is_e071 TYPE e071.
ENDCLASS.

CLASS lcl_app IMPLEMENTATION.

  METHOD constructor.

    me->mv_trkorr = iv_trkorr.
    me->mv_devc = iv_devc.

  ENDMETHOD.

  METHOD main.
    DATA: lt_e071 TYPE TABLE OF e071.

* don't select entries with 'M' (Drop/Create)
    SELECT * FROM e071 INTO TABLE lt_e071 WHERE trkorr = mv_trkorr
                       AND pgmid <> 'CORR'
                       AND NOT pgmid LIKE '*%'
                       AND NOT object IN ('TABU','TDAT','VDAT','CDAT', 'SHI6', 'SHI3', 'ADIR')
                       AND objfunc IN (' ',gc_deleted).



    CALL FUNCTION 'EMINT_CHECK_EXIST'
      TABLES
        ct_e071 = lt_e071.


    LOOP AT lt_e071 ASSIGNING FIELD-SYMBOL(<ls_e071>).
      IF <ls_e071>-objfunc = ' '.             "object doesn't exist
        <ls_e071>-objfunc = gc_deleted.
        insert_tadir(  <ls_e071> ).

      ELSE.
        <ls_e071>-objfunc = ' '.
      ENDIF.
    ENDLOOP.

    UPDATE e071 FROM TABLE lt_e071.

  ENDMETHOD.
  METHOD insert_tadir.
    IF  is_e071-pgmid  <> 'R3TR'.
      WRITE / |Object { is_e071-pgmid  } { is_e071-object } { is_e071-obj_name } skipped, as it is not main object.|.
      RETURN.
    ENDIF.

    CALL FUNCTION 'TRINT_TADIR_MODIFY'
      EXPORTING
        author               = sy-uname      " Object author
        DEVCLASS = mv_devc
        masterlang           = sy-langu      " Object was generated in this language
        object               = is_e071-object   " Object subtype (PROG, TABL ...)
        obj_name             = CONV sobj_name( is_e071-obj_name ) " Object name
        pgmid                = is_e071-pgmid    " Object type (R3TR, R3OB, ...)
        force_mode           = space
      EXCEPTIONS
        object_exists_global = 1        " Object already exists globally
        object_exists_local  = 2        " Object already exists locally
        object_has_no_tadir  = 3        " Object does not exist locally
        OTHERS               = 4.

    CASE sy-subrc.
      WHEN 0.
        WRITE / |Object entry created/modified for: { is_e071-pgmid  } { is_e071-object } { is_e071-obj_name }.|.
      WHEN 1.
        WRITE / |Object already exists globally: { is_e071-pgmid  } { is_e071-object } { is_e071-obj_name }.|.
      WHEN 2.
        WRITE / |Object already exists locally: { is_e071-pgmid  } { is_e071-object } { is_e071-obj_name }.|.
      WHEN 3.
        WRITE / |Object does not exist locally: { is_e071-pgmid  } { is_e071-object } { is_e071-obj_name }.|.

    ENDCASE.



  ENDMETHOD.

ENDCLASS.

START-OF-SELECTION.

  NEW lcl_app( iv_trkorr = p_trkorr iv_devc = p_devc )->main(  ).
