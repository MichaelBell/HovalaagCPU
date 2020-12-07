// Copyright (C) 2020 Michael Bell
//
// Inject program and input data to Basys2 development board for
// Hovalaag CPU testing.
//
// Reads program from "a.out" and input data from "input.bin"
// input.bin contains binary data to stream into IN1

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "dpcdecl.h" 
#include "depp.h"
#include "dmgr.h"

#define DeviceName "Basys2"
#define BinFileName "a.out"
#define InputBinFileName "input.bin"
#define InputTxtFileName "input.txt"

uint8_t* BuildBinRegSet(size_t* regSetLen);
uint8_t* BuildInputRegSet(FILE* inFile, size_t* regSetLen, bool* moreData);

bool isTextFile = false;

int main(int argc, char* argv[])
{
  HIF hif;

  if (argc == 2 && !strcmp(argv[1], "-t")) isTextFile = true;

  if (!DmgrOpen(&hif, DeviceName))
  {
    printf("Failed to open device\n");
    return 1;
  }

  if (!DeppEnable(hif))
  {
    printf("Failed to enable DEPP transfer\n");
    DmgrClose(hif);
    return 1;
  }

  FILE* inFile = fopen(isTextFile ? InputTxtFileName : InputBinFileName, "rb");
  if (!inFile)
  {
    printf("Failed to open input file\n");
    return NULL;
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

  while (true)
  {
    bool moreData = false;
    regSetPairs = BuildInputRegSet(inFile, &regSetLen, &moreData);
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

    if (!moreData) break;

    free(regSetPairs);
    regSetPairs = NULL;

    while (true)
    {
      uint8_t data;
      if (!DeppGetReg(hif, 7, &data, 0))
      {
        printf("RegGet failed.\n");
        rv = 5;
        goto EXIT;
      }
      if (data == 1) break;
      usleep(10000);
    }
  }

EXIT:
  fclose(inFile);
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
  uint8_t binaryProgram[1028];
  memset(binaryProgram + fileSize, 0, 1028 - fileSize);
  fread(binaryProgram, 1, fileSize, binFile);
  size_t programSize = fileSize / 4;
  
  // Produce address/data pairs for programming
  uint8_t* regSetPairs = (uint8_t*)malloc((programSize + 1) * 7 * 2 + 2);
  for (size_t i = 0; i <= programSize; ++i)
  {
    uint8_t* instr = &regSetPairs[i * 7 * 2];
    for (int j = 0; j < 6; ++j)
      instr[j*2] = j;
    instr[1] = 1;
    instr[3] = i;
    for (int j = 0; j < 4; ++j)
      instr[5 + j * 2] = binaryProgram[i * 4 + 3 - j];
    instr[12] = 0;
    instr[13] = (i == programSize) ? 0xc1 : 0x81;
  }

  regSetPairs[programSize * 7 * 2] = 0;
  regSetPairs[programSize * 7 * 2 + 1] = 0;

  fclose(binFile);

  *regSetLen = (programSize + 1) * 7 + 1;
  return regSetPairs;
}

#define NUM_DATA_WORDS 2048

uint8_t* BuildInputRegSet(FILE* inFile, size_t* regSetLen, bool* moreData)
{
  int16_t in1[NUM_DATA_WORDS];
  uint8_t in1bin[NUM_DATA_WORDS];
  int in1Len = 0;

  if (isTextFile)
  {
    for (int i = 0; i < NUM_DATA_WORDS && !feof(inFile); ++i)
    {
      char buf[256];
      if (!fgets(buf, sizeof(buf), inFile)) break;

      int numRead = sscanf(buf, "%hd", &in1[i]);
      if (numRead == 0) break;
      in1Len++;
    }
  }
  else 
  {
    in1Len = fread(in1bin, 1, NUM_DATA_WORDS, inFile);
    printf("Read %d bytes binary input\n", in1Len);
    for (int i = 0; i < in1Len; ++i)
      in1[i] = in1bin[i];
  }

  if (in1Len == 0) return NULL;

  *regSetLen = in1Len * 6 * 2 + 2;
  if (in1Len < NUM_DATA_WORDS)
  {
    in1[in1Len] = 0;
    *regSetLen += 6 * 2;
    *moreData = false;
  }
  else
  {
    *moreData = true;
  }

  // Produce address/data pairs for programming
  uint8_t* regSetPairs = (uint8_t*)malloc(*regSetLen);
  for (size_t i = 0; i < NUM_DATA_WORDS; ++i)
  {
    uint8_t* instr = &regSetPairs[i * 6 * 2];
    for (int j = 0; j < 4; ++j)
      instr[j*2] = j;
    instr[1] = 2;
    instr[3] = i & 0xff;
    instr[5] = in1[i] >> 8;
    instr[7] = in1[i] & 0xff;
    instr[8] = 6;
    instr[9] = i >> 8;
    instr[10] = 0;
    instr[11] = 0x82;
    if (i == in1Len)
    {
      instr[11] = 0xc2;
      break;
    }
  }

  regSetPairs[*regSetLen - 2] = 0;
  regSetPairs[*regSetLen - 1] = 0;

  *regSetLen /= 2;

  return regSetPairs;
}
