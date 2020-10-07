// Copyright (C) 2020 Michael Bell
//
// Inject program and input data to Basys2 development board for
// Hovalaag CPU testing.
//
// Reads program from "a.out" and input data from "input.txt"
// input.txt should contain columns of input data (in decimal),
// for example:
// 45      1     46     44
// 24     18     42      6
// 63      9     72     54
// 91     13    104     78
// The first two columns are set as the IN1 and IN2 input data,
// any remaining columns are ignored.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "dpcdecl.h" 
#include "depp.h"
#include "dmgr.h"

#define DeviceName "Basys2"
#define BinFileName "a.out"
#define InputFileName "input.txt"

uint8_t* BuildBinRegSet(size_t* regSetLen);
uint8_t* BuildInputRegSet(size_t* regSetLen);

int main(int argc, char* argv[])
{
  HIF hif;

  if (!DmgrOpen(&hif, DeviceName))
  {
    printf("Failed to open device\n");
    return 1;
  }

  if (!DeppEnable(hif))
  {
    printf("Failed to enable DEPP transfer\n");
    return 1;
  }

  int rv = 0;
  size_t regSetLen;
  uint8_t* regSetPairs = BuildBinRegSet(&regSetLen);
  if (!regSetPairs)
  {
    rv = 2;
    goto EXIT;
  }
  
  if (!DeppPutRegSet(hif, regSetPairs, regSetLen, false))
  {
    printf("RegSet failed.\n");
    rv = 3;
    goto EXIT;
  }
  free(regSetPairs);

  regSetPairs = BuildInputRegSet(&regSetLen);
  if (!regSetPairs)
  {
    rv = 4;
    goto EXIT;
  }
  
  if (!DeppPutRegSet(hif, regSetPairs, regSetLen, false))
  {
    printf("RegSet failed.\n");
    rv = 3;
    goto EXIT;
  }

EXIT:
  free(regSetPairs);
  DeppDisable(hif);
  DmgrClose(hif);
  return rv;
}

// Build the address/data pairs for programming the Hovalaag from the a.out binary
// Allocates the buffer, which should be freed by the caller.
uint8_t* BuildBinRegSet(size_t* regSetLen)
{
  FILE* binFile = fopen(BinFileName, "rb");
  if (!binFile)
  {
    printf("Failed to open " BinFileName "\n");
    return NULL;
  }

  // Determine file size
  fseek(binFile, 0, SEEK_END);
  size_t fileSize = ftell(binFile);
  fseek(binFile, 0, SEEK_SET);
  if ((fileSize % 4) != 0 || fileSize > 1024)
  {
    printf("Invalid program\n");
    fclose(binFile);
    return NULL;
  }

  // Read file
  uint8_t binaryProgram[1024];
  fread(binaryProgram, 1, fileSize, binFile);
  size_t programSize = fileSize / 4;
  
  // Produce address/data pairs for programming
  uint8_t* regSetPairs = (uint8_t*)malloc(programSize * 7 * 2 + 2);
  for (size_t i = 0; i < programSize; ++i)
  {
    uint8_t* instr = &regSetPairs[i * 7 * 2];
    for (int j = 0; j < 6; ++j)
      instr[j*2] = j;
    instr[1] = 1;
    instr[3] = i;
    for (int j = 0; j < 4; ++j)
      instr[5 + j * 2] = binaryProgram[i * 4 + 3 - j];
    instr[12] = 0;
    instr[13] = 0x81;
  }

  regSetPairs[programSize * 7 * 2] = 0;
  regSetPairs[programSize * 7 * 2 + 1] = 0;

  fclose(binFile);

  *regSetLen = programSize * 7 * 2;
  return regSetPairs;
}

uint8_t* BuildInputRegSet(size_t* regSetLen)
{
  FILE* inFile = fopen(InputFileName, "rb");
  if (!inFile)
  {
    printf("Failed to open " InputFileName "\n");
    return NULL;
  }

  short int in1[257];
  short int in2[257];
  int in1Len = 0;
  int in2Len = 0;

  for (int i = 0; i < 256 && !feof(inFile); ++i)
  {
    char buf[256];
    if (!fgets(buf, sizeof(buf), inFile)) break;

    int numRead = sscanf(buf, "%hd %hd", &in1[i], &in2[i]);
    if (numRead == 0) break;
    in1Len++;
    if (numRead == 2) in2Len++;
  }

  in1[in1Len] = 0;
  in2[in2Len] = 0;

  // Produce address/data pairs for programming
  uint8_t* regSetPairs = (uint8_t*)malloc((in1Len + in2Len + 2) * 5 * 2 + 2);
  for (size_t i = 0; i <= in1Len; ++i)
  {
    uint8_t* instr = &regSetPairs[i * 5 * 2];
    for (int j = 0; j < 4; ++j)
      instr[j*2] = j;
    instr[1] = 2;
    instr[3] = i;
    instr[5] = in1[i] >> 8;
    instr[7] = in1[i] & 0xff;
    instr[8] = 0;
    instr[9] = (i == in1Len) ? 0xc2 : 0x82;
  }
  for (size_t i = 0; i <= in2Len; ++i)
  {
    uint8_t* instr = &regSetPairs[(i + in1Len + 1) * 5 * 2];
    for (int j = 0; j < 4; ++j)
      instr[j*2] = j;
    instr[1] = 3;
    instr[3] = i;
    instr[5] = in2[i] >> 8;
    instr[7] = in2[i] & 0xff;
    instr[8] = 0;
    instr[9] = (i == in1Len) ? 0xc3 : 0x83;
  }

  regSetPairs[(in1Len + in2Len + 2) * 5 * 2] = 0;
  regSetPairs[(in1Len + in2Len + 2) * 5 * 2 + 1] = 0;

  fclose(inFile);

  *regSetLen = (in1Len + in2Len + 2) * 5 * 2 + 2;
  return regSetPairs;
}
