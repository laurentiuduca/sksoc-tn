// See LICENSE for license details.
/****************************************************************************
 * Included Files
 ****************************************************************************/

#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <string.h>
#include <debug.h>
#include <math.h>

extern int tints;

//**************************************************************************
// Dhrystone bencmark
//--------------------------------------------------------------------------
//
// This is the classic Dhrystone synthetic integer benchmark.
//

#pragma GCC optimize ("no-inline")

#include "dhrystone.h"

#include <alloca.h>

int core_main(int argc, char *argv[]);

#define setStats(x)

#define read_csr(reg) ({ unsigned long __tmp; \
  asm volatile ("csrr %0, " #reg : "=r"(__tmp)); \
  __tmp; })

/* Global Variables: */

Rec_Pointer     Ptr_Glob,
                Next_Ptr_Glob;
int             Int_Glob;
Boolean         Bool_Glob;
char            Ch_1_Glob,
                Ch_2_Glob;
int             Arr_1_Glob [50];
int             Arr_2_Glob [50] [50];

Proc_7 (Int_1_Par_Val, Int_2_Par_Val, Int_Par_Ref)
/**********************************************/
    /* executed three times                                      */
    /* first call:      Int_1_Par_Val == 2, Int_2_Par_Val == 3,  */
    /*                  Int_Par_Ref becomes 7                    */
    /* second call:     Int_1_Par_Val == 10, Int_2_Par_Val == 5, */
    /*                  Int_Par_Ref becomes 17                   */
    /* third call:      Int_1_Par_Val == 6, Int_2_Par_Val == 10, */
    /*                  Int_Par_Ref becomes 18                   */
One_Fifty       Int_1_Par_Val;
One_Fifty       Int_2_Par_Val;
One_Fifty      *Int_Par_Ref;
{
  One_Fifty Int_Loc;

  Int_Loc = Int_1_Par_Val + 2;
  *Int_Par_Ref = Int_2_Par_Val + Int_Loc;
} /* Proc_7 */


Proc_3 (Ptr_Ref_Par)
/******************/
    /* executed once */
    /* Ptr_Ref_Par becomes Ptr_Glob */

Rec_Pointer *Ptr_Ref_Par;

{
  if (Ptr_Glob != Null)
    /* then, executed */
    *Ptr_Ref_Par = Ptr_Glob->Ptr_Comp;
  Proc_7 (10, Int_Glob, &Ptr_Glob->variant.var_1.Int_Comp);
} /* Proc_3 */


Proc_4 () /* without parameters */
/*******/
    /* executed once */
{
  Boolean Bool_Loc;

  Bool_Loc = Ch_1_Glob == 'A';
  Bool_Glob = Bool_Loc | Bool_Glob;
  Ch_2_Glob = 'B';
} /* Proc_4 */


Proc_5 () /* without parameters */
/*******/
    /* executed once */
{
  Ch_1_Glob = 'A';
  Bool_Glob = false;
} /* Proc_5 */

// dhrystone.c
#ifndef REG
#define REG
        /* REG becomes defined as empty */
        /* i.e. no register variables   */
#else
#undef REG
#define REG register
#endif

extern  int     Int_Glob;
extern  char    Ch_1_Glob;

Boolean Func_3 (Enum_Par_Val)
/***************************/
    /* executed once        */
    /* Enum_Par_Val == Ident_3 */
Enumeration Enum_Par_Val;
{
  Enumeration Enum_Loc;

  Enum_Loc = Enum_Par_Val;
  if (Enum_Loc == Ident_3)
    /* then, executed */
    return (true);
  else /* not executed */
    return (false);
} /* Func_3 */

Proc_6 (Enum_Val_Par, Enum_Ref_Par)
/*********************************/
    /* executed once */
    /* Enum_Val_Par == Ident_3, Enum_Ref_Par becomes Ident_2 */

Enumeration  Enum_Val_Par;
Enumeration *Enum_Ref_Par;
{
  *Enum_Ref_Par = Enum_Val_Par;
  if (! Func_3 (Enum_Val_Par))
    /* then, not executed */
    *Enum_Ref_Par = Ident_4;
  switch (Enum_Val_Par)
  {
    case Ident_1: 
      *Enum_Ref_Par = Ident_1;
      break;
    case Ident_2: 
      if (Int_Glob > 100)
        /* then */
      *Enum_Ref_Par = Ident_1;
      else *Enum_Ref_Par = Ident_4;
      break;
    case Ident_3: /* executed */
      *Enum_Ref_Par = Ident_2;
      break;
    case Ident_4: break;
    case Ident_5: 
      *Enum_Ref_Par = Ident_3;
      break;
  } /* switch */
} /* Proc_6 */

Proc_8 (Arr_1_Par_Ref, Arr_2_Par_Ref, Int_1_Par_Val, Int_2_Par_Val)
/*********************************************************************/
    /* executed once      */
    /* Int_Par_Val_1 == 3 */
    /* Int_Par_Val_2 == 7 */
Arr_1_Dim       Arr_1_Par_Ref;
Arr_2_Dim       Arr_2_Par_Ref;
int             Int_1_Par_Val;
int             Int_2_Par_Val;
{
  REG One_Fifty Int_Index;
  REG One_Fifty Int_Loc;

  Int_Loc = Int_1_Par_Val + 5;
  Arr_1_Par_Ref [Int_Loc] = Int_2_Par_Val;
  Arr_1_Par_Ref [Int_Loc+1] = Arr_1_Par_Ref [Int_Loc];
  Arr_1_Par_Ref [Int_Loc+30] = Int_Loc;
  for (Int_Index = Int_Loc; Int_Index <= Int_Loc+1; ++Int_Index)
    Arr_2_Par_Ref [Int_Loc] [Int_Index] = Int_Loc;
  Arr_2_Par_Ref [Int_Loc] [Int_Loc-1] += 1;
  Arr_2_Par_Ref [Int_Loc+20] [Int_Loc] = Arr_1_Par_Ref [Int_Loc];
  Int_Glob = 5;
} /* Proc_8 */

Enumeration Func_1 (Ch_1_Par_Val, Ch_2_Par_Val)
/*************************************************/
    /* executed three times                                         */
    /* first call:      Ch_1_Par_Val == 'H', Ch_2_Par_Val == 'R'    */
    /* second call:     Ch_1_Par_Val == 'A', Ch_2_Par_Val == 'C'    */
    /* third call:      Ch_1_Par_Val == 'B', Ch_2_Par_Val == 'C'    */

Capital_Letter   Ch_1_Par_Val;
Capital_Letter   Ch_2_Par_Val;
{
  Capital_Letter        Ch_1_Loc;
  Capital_Letter        Ch_2_Loc;

  Ch_1_Loc = Ch_1_Par_Val;
  Ch_2_Loc = Ch_1_Loc;
  if (Ch_2_Loc != Ch_2_Par_Val)
    /* then, executed */
    return (Ident_1);
  else  /* not executed */
  {
    Ch_1_Glob = Ch_1_Loc;
    return (Ident_2);
   }
} /* Func_1 */

Boolean Func_2 (Str_1_Par_Ref, Str_2_Par_Ref)
/*************************************************/
    /* executed once */
    /* Str_1_Par_Ref == "DHRYSTONE PROGRAM, 1'ST STRING" */
    /* Str_2_Par_Ref == "DHRYSTONE PROGRAM, 2'ND STRING" */

Str_30  Str_1_Par_Ref;
Str_30  Str_2_Par_Ref;
{
  REG One_Thirty        Int_Loc;
      Capital_Letter    Ch_Loc;

  Int_Loc = 2;
  while (Int_Loc <= 2) /* loop body executed once */
    if (Func_1 (Str_1_Par_Ref[Int_Loc],
                Str_2_Par_Ref[Int_Loc+1]) == Ident_1)
      /* then, executed */
    {
      Ch_Loc = 'A';
      Int_Loc += 1;
    } /* if, while */
  if (Ch_Loc >= 'W' && Ch_Loc < 'Z')
    /* then, not executed */
    Int_Loc = 7;
  if (Ch_Loc == 'R')
    /* then, not executed */
    return (true);
  else /* executed */
  {
    if (strcmp (Str_1_Par_Ref, Str_2_Par_Ref) > 0)
      /* then, not executed */
    {
      Int_Loc += 7;
      Int_Glob = Int_Loc;
      return (true);
    }
    else /* executed */
      return (false);
  } /* if Ch_Loc */
} /* Func_2 */

// end of dhrystone.c

Enumeration     Func_1 ();
  /* forward declaration necessary since Enumeration may not simply be int */

#ifndef REG
        Boolean Reg = false;
#define REG
        /* REG becomes defined as empty */
        /* i.e. no register variables   */
#else
        Boolean Reg = true;
#undef REG
#define REG register
#endif

Boolean		Done;

long            Begin_Time,
                End_Time,
                User_Time;
long            Microseconds,
                Dhrystones_Per_Second;

/* end of variables for time measurement */



Proc_1 (Ptr_Val_Par)
/******************/

REG Rec_Pointer Ptr_Val_Par;
    /* executed once */
{
  REG Rec_Pointer Next_Record = Ptr_Val_Par->Ptr_Comp;  
                                        /* == Ptr_Glob_Next */
  /* Local variable, initialized with Ptr_Val_Par->Ptr_Comp,    */
  /* corresponds to "rename" in Ada, "with" in Pascal           */
  
  structassign (*Ptr_Val_Par->Ptr_Comp, *Ptr_Glob); 
  Ptr_Val_Par->variant.var_1.Int_Comp = 5;
  Next_Record->variant.var_1.Int_Comp 
        = Ptr_Val_Par->variant.var_1.Int_Comp;
  Next_Record->Ptr_Comp = Ptr_Val_Par->Ptr_Comp;
  Proc_3 (&Next_Record->Ptr_Comp);
    /* Ptr_Val_Par->Ptr_Comp->Ptr_Comp 
                        == Ptr_Glob->Ptr_Comp */
  if (Next_Record->Discr == Ident_1)
    /* then, executed */
  {
    Next_Record->variant.var_1.Int_Comp = 6;
    Proc_6 (Ptr_Val_Par->variant.var_1.Enum_Comp, 
           &Next_Record->variant.var_1.Enum_Comp);
    Next_Record->Ptr_Comp = Ptr_Glob->Ptr_Comp;
    Proc_7 (Next_Record->variant.var_1.Int_Comp, 10, 
           &Next_Record->variant.var_1.Int_Comp);
  }
  else /* not executed */
    structassign (*Ptr_Val_Par, *Ptr_Val_Par->Ptr_Comp);
} /* Proc_1 */


Proc_2 (Int_Par_Ref)
/******************/
    /* executed once */
    /* *Int_Par_Ref == 1, becomes 4 */

One_Fifty   *Int_Par_Ref;
{
  One_Fifty  Int_Loc;  
  Enumeration   Enum_Loc;

  Int_Loc = *Int_Par_Ref + 10;
  do /* executed once */
    if (Ch_1_Glob == 'A')
      /* then, executed */
    {
      Int_Loc -= 1;
      *Int_Par_Ref = Int_Loc - Int_Glob;
      Enum_Loc = Ident_1;
    } /* if */
  while (Enum_Loc != Ident_1); /* true */
} /* Proc_2 */


#define wait_not_busy(baddr, status) \
          do { \
                nxsig_usleep(10); \
                status = *(volatile int *)(baddr - 0x200); \
                /*if(status & 0x100ff) _info("r status=%x\n", status);*/ \
          } while ((status & 0x100ff))
volatile unsigned char *baddr;
unsigned char b[512]={0};
void testsd()
{
        volatile int i, status=0;
        baddr = 0x40008200;
	int sector=4096, match=1;

      for(i = 0; i < 0x200; i++)
	      b[i] = i;
      // fill hw buffer with user data
      for(i = 0; i < 0x200; i++) {
                *(volatile unsigned char*)(baddr+i) = b[i];
        }
      /* Then transfer the sector */
      *(volatile int *)(baddr - 0x200 + 4) = sector;
      // wait writing
      wait_not_busy(baddr, status);

      // read block 0 
      sector = 0;
      // tell hw what sector to read
      *(volatile int *)(baddr - 0x200 + 0) = sector;
      // wait for the hardware to fill its buffer
      wait_not_busy(baddr, status);
      for(i=0; i<0x200; i++)
        b[i] = *(volatile unsigned char *)(baddr + i);
      //_info("\nsector %d: ", sector);
      //for(i=0; i<0x200; i++)
      //       _info("b[%d]=%d ", i, b[i]);

      // read block 4096
      sector = 4096;
      // tell hw what sector to read
      *(volatile int *)(baddr - 0x200 + 0) = sector;
      // wait for the hardware to fill its buffer
      wait_not_busy(baddr, status);
      for(i=0; i<0x200; i++)
        b[i] = *(volatile unsigned char *)(baddr + i);

      // check b[i]
      //_info("\nsector %d: ", sector);
      //for(i=0; i<0x200; i++)
      //        _info("b[%d]=%d ", i, b[i]);
      match = 1;
      for(i=0; i<0x200; i++)
	if(b[i] != (unsigned char)i)
		match = 0;
      if(match)
	     	_info("block match\n");
      else
		_info("block unmatch\n");
}

int t0=0, t1=0;

int sdc_main(void);
int main(int argc, FAR char *argv[])
/*****/
  /* main program, corresponds to procedures        */
  /* Main and Proc_0 in the Ada version             */
{

	//sdc_main();
	//testsd();

#if 0
  float a=1.5, b=2.6;
  _info("a+b=%f\n", a*b);
  while(1);
#endif

        One_Fifty       Int_1_Loc;
  REG   One_Fifty       Int_2_Loc;
        One_Fifty       Int_3_Loc;
  REG   char            Ch_Index;
        Enumeration     Enum_Loc;
        Str_30          Str_1_Loc;
        Str_30          Str_2_Loc;
  REG   int             Run_Index;
  REG   int             Number_Of_Runs;

  /* Arguments */
  Number_Of_Runs = NUMBER_OF_RUNS;

  /* Initializations */

  Next_Ptr_Glob = (Rec_Pointer) alloca (sizeof (Rec_Type));
  Ptr_Glob = (Rec_Pointer) alloca (sizeof (Rec_Type));

  Ptr_Glob->Ptr_Comp                    = Next_Ptr_Glob;
  Ptr_Glob->Discr                       = Ident_1;
  Ptr_Glob->variant.var_1.Enum_Comp     = Ident_3;
  Ptr_Glob->variant.var_1.Int_Comp      = 40;
  strcpy (Ptr_Glob->variant.var_1.Str_Comp, 
          "DHRYSTONE PROGRAM, SOME STRING");
  strcpy (Str_1_Loc, "DHRYSTONE PROGRAM, 1'ST STRING");

  Arr_2_Glob [8][7] = 10;
        /* Was missing in published program. Without this statement,    */
        /* Arr_2_Glob [8][7] would have an undefined value.             */
        /* Warning: With 16-Bit processors and Number_Of_Runs > 32000,  */
        /* overflow may occur for this array element.                   */

  _info("\n");
  _info("Dhrystone Benchmark, Version %s\n", Version);
  if (Reg)
  {
    _info("Program compiled with 'register' attribute\n");
  }
  else
  {
    _info("Program compiled without 'register' attribute\n");
  }
  _info("Using %s, HZ=%d\n", CLOCK_TYPE, HZ);
  _info("\n");

  Done = false;
  while (!Done) {
    _info("Trying %d runs through Dhrystone:\n", Number_Of_Runs);

    /***************/
    /* Start timer */
    /***************/

    setStats(1);
    Start_Timer();
    t0 = read_csr(mcycle);

    for (Run_Index = 1; Run_Index <= Number_Of_Runs; ++Run_Index)
    {

      Proc_5();
      Proc_4();
	/* Ch_1_Glob == 'A', Ch_2_Glob == 'B', Bool_Glob == true */
      Int_1_Loc = 2;
      Int_2_Loc = 3;
      strcpy (Str_2_Loc, "DHRYSTONE PROGRAM, 2'ND STRING");
      Enum_Loc = Ident_2;
      Bool_Glob = ! Func_2 (Str_1_Loc, Str_2_Loc);
	/* Bool_Glob == 1 */
      while (Int_1_Loc < Int_2_Loc)  /* loop body executed once */
      {
	Int_3_Loc = 5 * Int_1_Loc - Int_2_Loc;
	  /* Int_3_Loc == 7 */
	Proc_7 (Int_1_Loc, Int_2_Loc, &Int_3_Loc);
	  /* Int_3_Loc == 7 */
	Int_1_Loc += 1;
      } /* while */
	/* Int_1_Loc == 3, Int_2_Loc == 3, Int_3_Loc == 7 */
      Proc_8 (Arr_1_Glob, Arr_2_Glob, Int_1_Loc, Int_3_Loc);
	/* Int_Glob == 5 */
      Proc_1 (Ptr_Glob);
      for (Ch_Index = 'A'; Ch_Index <= Ch_2_Glob; ++Ch_Index)
			       /* loop body executed twice */
      {
	if (Enum_Loc == Func_1 (Ch_Index, 'C'))
	    /* then, not executed */
	  {
	  Proc_6 (Ident_1, &Enum_Loc);
	  strcpy (Str_2_Loc, "DHRYSTONE PROGRAM, 3'RD STRING");
	  Int_2_Loc = Run_Index;
	  Int_Glob = Run_Index;
	  }
      }
	/* Int_1_Loc == 3, Int_2_Loc == 3, Int_3_Loc == 7 */
      Int_2_Loc = Int_2_Loc * Int_1_Loc;
      Int_1_Loc = Int_2_Loc / Int_3_Loc;
      Int_2_Loc = 7 * (Int_2_Loc - Int_3_Loc) - Int_1_Loc;
	/* Int_1_Loc == 1, Int_2_Loc == 13, Int_3_Loc == 7 */
      Proc_2 (&Int_1_Loc);
	/* Int_1_Loc == 5 */

    } /* loop "for Run_Index" */

    /**************/
    /* Stop timer */
    /**************/

    Stop_Timer();
    t1 = read_csr(mcycle);
    setStats(0);

    User_Time = t1 - t0; // End_Time - Begin_Time;

    if (User_Time < Too_Small_Time)
    {
      _info("Measured time %d too small to obtain meaningful results %d\n", User_Time, Too_Small_Time);
      Number_Of_Runs = Number_Of_Runs * 10;
      _info("\n");
    } else Done = true;
  }

  _info("Final values of the variables used in the benchmark:\n");
  _info("\n");
  _info("Int_Glob:            %d\n", Int_Glob);
  _info("        should be:   %d\n", 5);
  _info("Bool_Glob:           %d\n", Bool_Glob);
  _info("        should be:   %d\n", 1);
  _info("Ch_1_Glob:           %c\n", Ch_1_Glob);
  _info("        should be:   %c\n", 'A');
  _info("Ch_2_Glob:           %c\n", Ch_2_Glob);
  _info("        should be:   %c\n", 'B');
  _info("Arr_1_Glob[8]:       %d\n", Arr_1_Glob[8]);
  _info("        should be:   %d\n", 7);
  _info("Arr_2_Glob[8][7]:    %d\n", Arr_2_Glob[8][7]);
  _info("        should be:   Number_Of_Runs + 10\n");
  _info("Ptr_Glob->\n");
  _info("  Ptr_Comp:          %d\n", (long) Ptr_Glob->Ptr_Comp);
  _info("        should be:   (implementation-dependent)\n");
  _info("  Discr:             %d\n", Ptr_Glob->Discr);
  _info("        should be:   %d\n", 0);
  _info("  Enum_Comp:         %d\n", Ptr_Glob->variant.var_1.Enum_Comp);
  _info("        should be:   %d\n", 2);
  _info("  Int_Comp:          %d\n", Ptr_Glob->variant.var_1.Int_Comp);
  _info("        should be:   %d\n", 17);
  _info("  Str_Comp:          %s\n", Ptr_Glob->variant.var_1.Str_Comp);
  _info("        should be:   DHRYSTONE PROGRAM, SOME STRING\n");
  _info("Next_Ptr_Glob->\n");
  _info("  Ptr_Comp:          %d\n", (long) Next_Ptr_Glob->Ptr_Comp);
  _info("        should be:   (implementation-dependent), same as above\n");
  _info("  Discr:             %d\n", Next_Ptr_Glob->Discr);
  _info("        should be:   %d\n", 0);
  _info("  Enum_Comp:         %d\n", Next_Ptr_Glob->variant.var_1.Enum_Comp);
  _info("        should be:   %d\n", 1);
  _info("  Int_Comp:          %d\n", Next_Ptr_Glob->variant.var_1.Int_Comp);
  _info("        should be:   %d\n", 18);
  _info("  Str_Comp:          %s\n",
                                Next_Ptr_Glob->variant.var_1.Str_Comp);
  _info("        should be:   DHRYSTONE PROGRAM, SOME STRING\n");
  _info("Int_1_Loc:           %d\n", Int_1_Loc);
  _info("        should be:   %d\n", 5);
  _info("Int_2_Loc:           %d\n", Int_2_Loc);
  _info("        should be:   %d\n", 13);
  _info("Int_3_Loc:           %d\n", Int_3_Loc);
  _info("        should be:   %d\n", 7);
  _info("Enum_Loc:            %d\n", Enum_Loc);
  _info("        should be:   %d\n", 1);
  _info("Str_1_Loc:           %s\n", Str_1_Loc);
  _info("        should be:   DHRYSTONE PROGRAM, 1'ST STRING\n");
  _info("Str_2_Loc:           %s\n", Str_2_Loc);
  _info("        should be:   DHRYSTONE PROGRAM, 2'ND STRING\n");
  _info("\n");


  Microseconds = ((User_Time / Number_Of_Runs) * Mic_secs_Per_Second) / HZ;
  Dhrystones_Per_Second = (HZ * Number_Of_Runs) / User_Time;

  _info("Microseconds for one run through Dhrystone: %ld\n", Microseconds);
  _info("Dhrystones per Second:                      %ld\n", Dhrystones_Per_Second);

  //int tints=0;
  _info("tints=%d, t1=%d, t0=%d\n", tints, t1, t0);

  core_main(0, 0);

  _info("tints=%d\n", tints);

  return 0;
}

