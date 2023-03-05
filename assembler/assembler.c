#define STB_DEFINE
#include "stb.h"  // http://github.com/nothings/stb

//#define MACHINE_CODE

#define VERSION "1.08"
#define DATE "2020-10-03"

FILE *html;
void fatal(char *s, ...)
{
   va_list a;
   va_start(a,s);
   vfprintf(stderr, s, a);
   va_end(a);
   if (html) {
      fprintf(html, "</table></body></html>\n");
      fclose(html);
   }
   exit(1);
}

typedef int Bool;
#define False 0
#define True  1

typedef struct
{
   uint8 w:2;
   uint8 a:2;
   uint8 b:2;
   uint8 c:2;

   uint8 alu:4;
   uint8 f:2;
   uint8 j:2;

   uint16 d:1;
   uint16 o:1;
   uint16 io:1;
   uint16 two_constants:1;
   int16  value:12;
} vls_instruction; // 32 bits

#define I(symbolic, string)          P(symbolic, string, P_none)

#define A_UNIT               \
   I(A_from_D  , "A=D")      \
   P(A_from_alu, "A=",P_alu) \
   I(A_from_in1, "A=IN1")    \
   I(A_from_in2, "A=IN2")    \

char *a_op[] = { "     " , "A=D, " , "A=M, " , "A=I1," , "A=I2," };
char *b_op[] = { "    "  , "B=A,"  , "B=M,"  , "B=K,"            };
char *c_op[] = { "      ", "C=M,  ", "DEC,  ", "DECNZ,",         };
char *d_op[] = { "    "  , "D=A,"                                };
char *w_op[] = { "    "  , "W=A,"  , "W=M,"  , "W=K,"            };
char *o_op[] = { "     " , "O1=W," , "O2=W,"                     };
char *f_op[] = { "       ", "F=Z(M),", "F=N(M),", "F=P(M),"      };
char *j_op[] = { "     " , "JMP, " , "JMPT," , "JMPF,"           };
char *m_op[] = { "M:0,    ", "M:-A,   ", "M:B,    ", "M:C,    ", "M:A>>1, ", "M:A+B,  ", "M:B-A,  ", "M:A+B+F,", "M:B-A-F,", "M:A|B,  ", "M:A&B,  ", "M:A^B,  ", "M:~A,   "};

#define B_UNIT                 \
   I(B_from_A,     "B=A")      \
   P(B_from_alu  , "B=",P_alu) \
   P(B_from_const, "B=",P_lit) \

#define C_UNIT                 \
   P(C_from_alu  , "C=",P_alu) \
   I(DEC         , "DEC")      \
   P(DECNZ       , "DECNZ ",P_label) \

#define D_UNIT             \
   I(D_from_A    , "D=A")

#define W_UNIT                 \
   I(W_from_A    , "W=A")      \
   P(W_from_alu  , "W=",P_alu) \
   P(W_from_const, "W=",P_lit) \

#define O_UNIT               \
   I(O_out1      , "OUT1=W") \
   I(O_out2      , "OUT2=W") \

#define F_UNIT                 \
   I(F_zero      , "F=ZERO()") \
   I(F_neg       , "F=NEG()")  \
   I(F_pos       , "F=POS()")  \

#define F_UNIT_2                    \
   P(F_zero      , "F=ZERO(",P_alu) \
   P(F_neg       , "F=NEG(" ,P_alu) \
   P(F_pos       , "F=POS(" ,P_alu) \

#define J_UNIT                       \
   P(J_jump      , "JMP " , P_label) \
   P(J_jump_true , "JMPT ", P_label) \
   P(J_jump_false, "JMPF ", P_label) \

#define P(a,b,c)  a,
enum a_unit { A_nop, A_UNIT };
enum b_unit { B_nop, B_UNIT };
enum c_unit { C_nop, C_UNIT };
enum d_unit { D_nop, D_UNIT };
enum w_unit { W_nop, W_UNIT };
enum o_unit { O_nop, O_UNIT };
enum f_unit { F_nop, F_UNIT };
enum j_unit { J_step,J_UNIT };
#undef P

typedef struct
{
   int instr;
   char *text;
   int param;
} vls_unit_opcode;

enum {
   P_none,
   P_lit,
   P_alu,
   P_label,
};


#define NUM_OPCODE_CLASSES   8
#define MAX_OPCODE_VARIANTS  6

#define P(a,b,c) { a,b,c },
vls_unit_opcode opcode[NUM_OPCODE_CLASSES][MAX_OPCODE_VARIANTS] = // F unit matches 6 strings
{
   { A_UNIT },
   { B_UNIT },
   { C_UNIT },
   { D_UNIT },
   { W_UNIT },
   { O_UNIT },
   { F_UNIT F_UNIT_2 },
   { J_UNIT },
};

#define NUM_ALU  13
char *alu[NUM_ALU] =
{
   "0",
   "-A",
   "B",
   "C",
   "A>>1",
   "A+B",
   "B-A",
   "A+B+F",
   "B-A-F",
   "A|B",
   "A&B",
   "A^B",
   "~A",
};

char *f_alu[NUM_ALU] =
{
   "0)",
   "-A)",
   "B)",
   "C)",
   "A>>1)",
   "A+B)",
   "B-A)",
   "A+B+F)",
   "B-A-F)",
   "A|B)",
   "A&B)",
   "A^B)",
   "~A)",
};

char *unit_names[9] = 
{
   "A unit", "B unit", "C unit", "D unit", "W unit", "O unit", "F unit", "J unit", "ALU"
};

stb_sdict *labels;

vls_instruction vls_assemble_instruction(char **unit_ops, int num_ops, int line_number)
{
   int start,offset;

   // if we fail to parse because we make a wrong ALU vs. const assignment, we need to
   // try again but start at a different place. if it is viable, one of the instructions
   // we start on will be the alu instruction. this requires alu cases in opcode[][] to
   // be before other cases so we force correctly

   for (start=0; start < num_ops; ++start) {
      int units[11] = { 0 }; // 8 = ALU, 9 = literal, 10 = loop target
      int io_slot = -1;
      Bool needs_alu=False;
      Bool has_alu=False;
      Bool has_constant=False;
      Bool has_io=False;
      Bool has_label=False;
      units[10] = -1;
      for (offset=0; offset < num_ops; ++offset) {
         int tok = (start + offset) % num_ops;
         int a,b,i;
         char *s = unit_ops[tok];
         for (a=0; a < NUM_OPCODE_CLASSES; ++a) {
            Bool alu_failed=0;
            Bool lit_failed=0;
            Bool alu_inconsistent=False;
            for (b=0; b < MAX_OPCODE_VARIANTS; ++b) {
               if (opcode[a][b].text != NULL) {
                  Bool success = False;
                  if (opcode[a][b].param != P_none) {
                     if (stb_prefix(s, opcode[a][b].text)) {
                        char *t = s + strlen(opcode[a][b].text);
                        t = stb_skipwhite(t);
                        switch (opcode[a][b].param) {
                           case P_alu: {
                              char **alu_strings = (a == 6 ? f_alu : alu);
                              for (i=0; i < NUM_ALU; ++i)
                                 if (0==strcmp(t, alu_strings[i]))
                                    break;
                              if (i == NUM_ALU)
                                 alu_failed = True;
                              else {
                                 if (has_alu && units[8] != i)
                                    alu_inconsistent = True;
                                 else {
                                    success = True;
                                    has_alu = True;
                                    units[8] = i;
                                 }
                              }
                              break;
                           }
                           case P_lit: {
                              char *post=0;
                              int v;
                              int neg = t[0] == '-' ? -1 : 1;
                              if (neg < 0) ++t;
                              if (*t == '$') {
                                 v = strtol(t+1, &post, 16) * neg;
                                 if (neg < 0) {
                                    if ((v << 20) >> 20 != v)
                                       fatal("ASM error, line %d: Constant %X would be truncated to %X.", line_number, v, ((v<<20)>>20) & 0xfff);
                                 } else {
                                    if ((v & 0xfff) != v)
                                       fatal("ASM error, line %d: Constant %X would be truncated to %X.", line_number, v, v & 0xfff);
                                 }
                                 success = True;
                              } else if (isdigit(*t)) {
                                 v = strtol(t, &post, 10) * neg;
                                 if ((v << 20) >> 20 != v)
                                    fatal("ASM error, line %d: Constant %d would be truncated to %d.", line_number, v, (v<<20)>>20);
                                 success = True;
                              } else {
                                 lit_failed = True; // can just throw the error here probably
                              }
                              if (success) {
                                 post = stb_skipwhite(post);
                                 if (*post != ';' && *post != 0)
                                    fatal("ASM error, line %d: Extra characters after constant %d.", line_number, v);
                                 if (has_constant && units[9] != v)
                                    goto inconsistent;
                                 if (units[10] >= 0 && units[10] != v && (units[10] >= 64 || v < -32 || v > 31))
                                    goto inconsistent;
                                 has_constant = True;
                                 units[9] = v;
                              }
                              break;
                           }
                           case P_label: {
                              int *address = stb_sdict_get(labels, t);
                              if (address == NULL)
                                 fatal("ASM error, line %d: Unknown label '%s' in %s.", line_number, t, unit_names[a]);
                              if (has_label && units[10] != *address)
                                 fatal("ASM error, line %d: Cannot branch to two different addresses in the same instruction.", line_number);
                              if (has_constant && units[9] != *address && (*address >= 64 || units[9] < -32 || units[9] > 31))
                                 goto inconsistent;
                              units[10] = *address;
                              has_label = True;
                              success = True;
                           }
                        }
                     }
                  } else {
                     if (!strcmp(s, opcode[a][b].text)) {
                        success = True;
                        if (a == 6) // F unit
                           needs_alu = True; // implicit ALU requires ALU exist
                     }
                  }

                  if (success) {
                     if (units[a] != 0)
                        fatal("ASM error, line %d: tried to use %s more than once.", line_number, unit_names[a]);
                     units[a] = opcode[a][b].instr;
                     goto parsed;
                  }
               }
            }
            if (alu_inconsistent)
               goto inconsistent;
            if (alu_failed && lit_failed)
               fatal("ASM error, line %d: unrecognized ALU operation or integer constant in %s.", line_number, unit_names[a]); 
            if (alu_failed)
               fatal("ASM error, line %d: unrecognized ALU operation in %s.", line_number, unit_names[a]);
            if (lit_failed)
               fatal("ASM error, line %d: unrecognized integer constant operation in %s.", line_number, unit_names[a]);
         }
         fatal("ASM error, line %d: unrecognized opcode after %d commas.", line_number, tok);
        parsed:
         ;
      }

      if (needs_alu && !has_alu)
         fatal("ASM error, line %d: F was assigned with implicit ALU, but no ALU operation was specified elsewhere.", line_number);

      {
         vls_instruction ins;
         int a_io_slot = -1, o_io_slot = -1;
         if (units[0] == A_from_in1 || units[0] == A_from_in2)
            a_io_slot = units[0] - A_from_in1;
         if (units[5] == O_out1 || units[5] == O_out2)
            o_io_slot = units[5] - O_out1;
         if (a_io_slot >= 0 && o_io_slot >= 0 && a_io_slot != o_io_slot)
            fatal("ASM error, line %d: Attempted to use IN and OUT in same instruction with different port numbers.", line_number);

         if (units[0] > A_from_in1) units[0] = A_from_in1;
         if (units[5] > O_out1)     units[5] = O_out1;
         ins.a = units[0];
         ins.b = units[1];
         ins.c = units[2];
         ins.d = units[3];
         ins.w = units[4];
         ins.o = units[5];
         ins.f = units[6];
         ins.j = units[7];
         ins.alu = units[8];
         if (units[10] >= 0 && has_constant && units[10] != units[9]) {
            if (units[10] >= 63 || units[9] < -32 || units[9] > 31)
               fatal("ASM error, line %d: internal error detecting constant mismatch");
            ins.value = (units[9] << 6) | units[10];
            ins.two_constants = 1;
         } else {
            ins.value = units[10] >= 0 ? units[10] : units[9];
            ins.two_constants = 0;
         }
         if (a_io_slot >= 0)
            ins.io = a_io_slot;
         else if (o_io_slot >= 0)
            ins.io = o_io_slot;
         else
            ins.io = 0;
         return ins;
      }
     inconsistent: 
      // if we tried to use the ALU two different ways, or use two different constants, try a different
      // ordering so the ALU gets assigned differently
      ; 
   }
   fatal("ASM error, line %d: couldn't find a consistent assignment of ALU and/or constants\n", line_number);

   // dummy NOTREACHED for compiler warning
   {
      vls_instruction x = { 0 };
      return x;
   }
}

vls_instruction program[65536];
char *label[65536];
int num_instructions=0;

static uint remap2(uint n, uint a, uint b)
{
   if (n == a) return b;
   if (n == b) return a;
   return n;
}

void vls_assemble(char *filename)
{
   int i,j,len,pc;
   char **lines = stb_stringfile(filename, &len);
   if (lines == NULL)
      fatal("Couldn't open '%s'.", filename);
   labels = stb_sdict_new(1);
   for (i=0; i < len; ++i) {
      char *s;
      // strip comments
      s = strchr(lines[i], ';');
      if (s) *s = 0;
      // trim trailing spaces
      stb_trimwhite(lines[i]);
      // force to upper-case
      for (s=lines[i]; *s; ++s)
         *s = toupper(*s);
   }

   // assign addresses to labels
   pc = 0;
   for (i=0; i < len; ++i) {
      if (lines[i][0] != 0 && !isspace(lines[i][0])) {
         // if first row isn't empty, it should be a label
         int *n;
         char *s = strchr(lines[i], ':');
         if (s == 0)
            fatal("ASM error, line %d: Labels must be terminated by ':'.", i+1);
         *s = 0;
         n = malloc(sizeof(*n));
         *n = pc;
         if (stb_sdict_get(labels, lines[i]))
            fatal("ASM error, line %d: Label defined more than once.", i+1);
         stb_sdict_add(labels, lines[i], n);
         label[pc] = strdup(lines[i]);
         if (strlen(label[pc]) > 6)
            label[pc][6] = 0;
         lines[i] = s+1;
      }
      lines[i] = stb_trimwhite(lines[i]);
      if (lines[i][0] != 0) {
         if (pc >= 255) fatal("ASM error, line %d: Program can be at most 255 instructions long.", i+1);
         ++pc;
      }
   }

   // assemble
   num_instructions = 0;
   for (i=0; i < len; ++i) {
      char *s = lines[i];
      if (s[0] != 0) {
         int num_ins;
         int reallocable=0;
         char **tokens = stb_tokens_stripwhite(s, ",", &num_ins);
         char **old_tokens = tokens;
         for (j=0; j < num_ins;) {
            if (tokens[j][1] == '=' && tokens[j][3] == '=') {
               char *s,*t;
               // multi-assignment needs to be split
               ++num_ins;
               if (reallocable)
                  tokens = realloc(tokens, sizeof(tokens[0]) * num_ins);
               else {
                  tokens = malloc(sizeof(tokens[0]) * num_ins);
                  memcpy(tokens, old_tokens, sizeof(tokens[0]) * (num_ins-1));
                  reallocable = 1;
               }
                  
               s = malloc(strlen(tokens[j])+1); // this is never freed!
               t = strrchr(tokens[j], '=');
               // the new token is the first LHS and the final RHS
               sprintf(s, "%c%s", tokens[j][0], t);
               tokens[num_ins-1] = s;
               // the old token loses the first LHS
               tokens[j] += 2;
               // now try again, in case there's more than two assignments in tokens[j]
            } else
               ++j;
         }
         program[num_instructions++] = vls_assemble_instruction(tokens, num_ins, i+1);
         free(old_tokens);
      }
   }

   if (num_instructions == 0)
      fatal("ASM error: program was empty\n");

#ifdef MACHINE_CODE
   #if 1
   {
      FILE *ff = fopen("a.out", "wb");
      int i;
      for (i=0; i < num_instructions; ++i) {
         uint32 ins;
         uint a,b,c,d,w,f,j,o,io,x,k,l,alu;
         vls_instruction v = program[i];
         alu = v.alu;
         a = remap2(v.a, 1,2);
         b = remap2(v.b, 1,2);
         c = v.c;
         d = v.d;
         w = remap2(v.w, 1,2);
         f = v.f;
         j = v.j;
         o = v.o;
         io = v.io;
         x = !v.two_constants;
         k = (v.value >> 6) & 63;
         l = v.value & 63;

         ins = (alu << 28) | (a<<26) | (b<<24) | (c<<22) | (d<<21) | (w<<19) | (f<<17) | (j<<15) | (o<<14) | (io<<13) | (x<<12) | (k<<6) | l;
         fwrite(&ins, 4, 1, ff);
      }
      fclose(ff);
   }
   #else
   stb_filewrite("a.out", program, sizeof(program[0]) * num_instructions);
   #endif
   exit(0);
#endif
}
