//
//  CubieCube.m
//  DCTimer Scramblers
//
//  Adapted from Shuang Chen's min2phase implementation of the Kociemba algorithm, as obtained from https://github.com/ChenShuang/min2phase
//
//  Copyright (c) 2013, Shuang Chen
//  All rights reserved.
//  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
//  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
//  Neither the name of the creator nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "CubieCube.h"
#import "Util.h"

@implementation CubieCube

int SymInv[16];
int SymMult[16][16];
int SymMove[16][18];
int Sym8Mult[8][8];
int Sym8Move[8][18];
int SymMoveUD[16][10];
int Sym8MultInv[8][8];

/**
 * ClassIndexToRepresentantArrays
 */
unsigned short FlipS2R[336];
unsigned short TwistS2R[324];
unsigned short EPermS2R[2768];

/**
 * Notice that Edge Perm Coordnate and Corner Perm Coordnate are the same symmetry structure.
 * So their ClassIndexToRepresentantArray are the same.
 * And when x is RawEdgePermCoordnate, y*16+k is SymEdgePermCoordnate, y*16+(k^e2c[k]) will
 * be the SymCornerPermCoordnate of the State whose RawCornerPermCoordnate is x.
 */
int e2c[] = {0, 0, 0, 0, 1, 3, 1, 3, 1, 3, 1, 3, 0, 0, 0, 0};
unsigned short MtoEPerm[40320];

/**
 * Raw-Coordnate to Sym-Coordnate, only for speeding up initializaion.
 */
unsigned short FlipR2S[2048];
unsigned short TwistR2S[2187];
unsigned short EPermR2S[40320];

/**
 *
 */
unsigned short SymStateTwist[324];
unsigned short SymStateFlip[336];
unsigned short SymStatePerm[2768];

extern int ud2std[];
extern int std2ud[];

// 16 symmetries generated by S_F2, S_U4 and S_LR2
+(NSMutableArray*)CubeSym {
    static NSMutableArray *cubeSym = nil;
    @synchronized(cubeSym) {
        if (!cubeSym) {
            cubeSym = [[NSMutableArray alloc] init];
            for (int x = 0; x < 16; x++) {
                [cubeSym addObject:[[CubieCube alloc] init]];
            }
        }
    }
    return cubeSym;
}

// 18 move cubes
+(NSMutableArray*)moveCube {
    static NSMutableArray *moveCube = nil;
    @synchronized(moveCube) {
        if (!moveCube) {
            moveCube = [[NSMutableArray alloc] init];
            for (int x = 0; x < 18; x++) {
                [moveCube addObject:[[CubieCube alloc] init]];
            }
        }
    }
    return moveCube;
}

+(CubieCube*) urf1 {
    static CubieCube *urf1 = nil;
    if (!urf1) {
        urf1 = [[super allocWithZone:NULL] initCubie:2531 twist:1373 eperm:67026819 flip:1367];
    }
    return urf1;
}

+(CubieCube*) urf2 {
    static CubieCube *urf2 = nil;
    if (!urf2) {
        urf2 = [[super allocWithZone:NULL] initCubie:2089 twist:1906 eperm:322752913 flip:2040];
    }
    return urf2;
}

CubieCube* temps = nil;

-(id)init {
    return  [self initCubie:UINT32_MAX twist:UINT32_MAX eperm:UINT32_MAX flip:UINT32_MAX];
}

-(id)initCubie:(int)cperm twist:(int)twist eperm:(int)eperm flip:(int)flip {
    if (self = [super init]) {
        for (int x = 0 ; x < 8; x++) {
            self->cp[x] = x;
            self->co[x] = 0;
        }
        for (int x = 0; x < 12; x++) {
            self->ep[x] = x;
            self->eo[x] = 0;
        }
        if (!(cperm == UINT32_MAX && UINT32_MAX == eperm && flip == UINT32_MAX)) {
            [self setCPerm:cperm];
            [self setTwist:twist];
            [Util setNPerm:ep i:eperm n:12];
            [self setFlip:flip];
        }
        
    }
    return self;
}

-(void)copyCubieCube:(CubieCube*)c {
    for (int i = 0; i < 8; i++) {
        self->cp[i] = c->cp[i];
        self->co[i] = c->co[i];
    }
    for (int i = 0; i < 12; i++) {
        self->ep[i] = c->ep[i];
        self->eo[i] = c->eo[i];
    }
}

-(void) invCubieCube {
    for (int edge=0; edge<12; edge++)
        temps->ep[ep[edge]] = edge;
    for (int edge=0; edge<12; edge++)
        temps->eo[edge] = eo[temps->ep[edge]];
    for (int corn=0; corn<8; corn++)
        temps->cp[cp[corn]] = corn;
    for (int corn=0; corn<8; corn++) {
        int ori = co[temps->cp[corn]];
        temps->co[corn] = -ori;
        if (temps->co[corn] < 0)
            temps->co[corn] += 3;
    }
    [self copyCubieCube:temps];
}

/**
 * prod = a * b, Corner Only.
 */
+(void) CornMult:(CubieCube*)a cubeB:(CubieCube*)b cubeProd:(CubieCube*)prod {
    for (int corn=0; corn<8; corn++) {
        prod->cp[corn] = a->cp[b->cp[corn]];
        int oriA = a->co[b->cp[corn]];
        int oriB = b->co[corn];
        int ori = oriA;
        ori += (oriA<3) ? oriB : 6-oriB;
        ori %= 3;
        if ((oriA >= 3) ^ (oriB >= 3)) {
            ori += 3;
        }
        prod->co[corn] = ori;
    }
}

/**
 * prod = a * b, Edge Only.
 */
+(void) EdgeMult:(CubieCube*)a cubeB:(CubieCube*)b cubeProd:(CubieCube*)prod {
    for (int ed=0; ed<12; ed++) {
        prod->ep[ed] = a->ep[b->ep[ed]];
        prod->eo[ed] = b->eo[ed] ^ a->eo[b->ep[ed]];
    }
}

/**
 * b = S_idx^-1 * a * S_idx, Corner Only.
 */
+(void) CornConjugate:(CubieCube*)a idx:(int)idx cubeB:(CubieCube*)b {
    //CubieCube sinv = CubeSym[SymInv[idx]];
    CubieCube *sinv = [[CubieCube CubeSym] objectAtIndex:SymInv[idx]];
    CubieCube *s = [[CubieCube CubeSym] objectAtIndex:idx];
    for (int corn=0; corn<8; corn++) {
        b->cp[corn] = sinv->cp[a->cp[s->cp[corn]]];
        int oriA = sinv->co[a->cp[s->cp[corn]]];
        int oriB = a->co[s->cp[corn]];
        b->co[corn] = (oriA<3) ? oriB : (3-oriB) % 3;
    }
}

/**
 * b = S_idx^-1 * a * S_idx, Edge Only.
 */
+(void) EdgeConjugate:(CubieCube*)a idx:(int)idx cubeB:(CubieCube*)b {
    CubieCube *sinv = [[CubieCube CubeSym] objectAtIndex:SymInv[idx]];
    CubieCube *s = [[CubieCube CubeSym] objectAtIndex:idx];
    for (int ed=0; ed<12; ed++) {
        b->ep[ed] = sinv->ep[a->ep[s->ep[ed]]];
        b->eo[ed] = s->eo[ed] ^ a->eo[s->ep[ed]] ^ sinv->eo[a->ep[s->ep[ed]]];
    }
}

/**
 * this = S_urf^-1 * this * S_urf.
 */
-(void) URFConjugate {
    if (temps == nil) {
        temps = [[CubieCube alloc] init];
    }
    [CubieCube CornMult:[CubieCube urf2] cubeB:self cubeProd:temps];
    [CubieCube CornMult:temps cubeB:[CubieCube urf1] cubeProd:self];
    [CubieCube EdgeMult:[CubieCube urf2] cubeB:self cubeProd: temps];
    [CubieCube EdgeMult:temps cubeB:[CubieCube urf1] cubeProd: self];
}

// ********************** Get and set coordinates ***********************
// XSym : Symmetry Coordnate of X. MUST be called after initialization of ClassIndexToRepresentantArrays.

// ++++++++++++++++++++ Phase 1 Coordnates ++++++++++++++++++++
// Flip : Orientation of 12 Edges. Raw[0, 2048) Sym[0, 336 * 8)
// Twist : Orientation of 8 Corners. Raw[0, 2187) Sym[0, 324 * 8)
// UDSlice : Positions of the 4 UDSlice edges, the order is ignored. [0, 495)

-(int) getFlip {
    int idx = 0;
    for (int i=0; i<11; i++) {
        idx <<= 1;
        idx |= eo[i];
    }
    return idx;
}

-(void) setFlip: (int)idx {
    int parity = 0;
    for (int i=10; i>=0; i--) {
        parity ^= eo[i] = idx & 1;
        idx >>= 1;
    }
    eo[11] = parity;
}

-(int) getFlipSym {
    return FlipR2S[[self getFlip]];
}

-(int) getTwist {
    int idx = 0;
    for (int i=0; i<7; i++) {
        idx *= 3;
        idx += co[i];
    }
    return idx;
}

-(void) setTwist:(int)idx {
    int twst = 0;
    for (int i=6; i>=0; i--) {
        twst += co[i] = idx % 3;
        idx /= 3;
    }
    co[7] = (15 - twst) % 3;
}

-(int) getTwistSym {
    return TwistR2S[[self getTwist]];
}

-(int) getUDSlice {
    return [Util getComb:ep m:8];
}

-(void) setUDSlice:(int)idx {
    [Util setComb:ep i:idx m:8];
}

-(int) getU4Comb {
    return [Util getComb:ep m:0];
}

-(int) getD4Comb {
    return [Util getComb:ep m:4];
}

// ++++++++++++++++++++ Phase 2 Coordnates ++++++++++++++++++++
// EPerm : Permutations of 8 UD Edges. Raw[0, 40320) Sym[0, 2187 * 16)
// Cperm : Permutations of 8 Corners. Raw[0, 40320) Sym[0, 2187 * 16)
// MPerm : Permutations of 4 UDSlice Edges. [0, 24)

-(int) getCPerm {
    return [Util get8Perm:cp];
}

-(void) setCPerm:(int) idx {
    [Util set8Perm:cp i:idx];
}

-(int) getCPermSym {
    int idx = EPermR2S[[self getCPerm]];
    idx ^= e2c[idx&0x0f];
    return idx;
}

-(int) getEPerm {
    return [Util get8Perm:ep];
}

-(void) setEPerm:(int) idx {
    [Util set8Perm:ep i:idx];
}

-(int) getEPermSym {
    return EPermR2S[[self getEPerm]];
}

-(int) getMPerm {
    return [Util getComb:ep m:8] >> 9;
}

-(void) setMPerm:(int) idx {
    [Util setComb:ep i:(idx<<9) m:8];
}

/**
 * Check a cubiecube for solvability. Return the error code.
 * 0: Cube is solvable
 * -2: Not all 12 edges exist exactly once
 * -3: Flip error: One edge has to be flipped
 * -4: Not all corners exist exactly once
 * -5: Twist error: One corner has to be twisted
 * -6: Parity error: Two corners or two edges have to be exchanged
 */
-(int) verify {
    int sum = 0;
    int edgeMask = 0;
    for (int e=0; e<12; e++)
        edgeMask |= (1 << ep[e]);
    if (edgeMask != 0x0fff)
        return -2;// missing edges
    for (int i=0; i<12; i++)
        sum ^= eo[i];
    if (sum % 2 != 0)
        return -3;
    int cornMask = 0;
    for (int c=0; c<8; c++)
        cornMask |= (1 << cp[c]);
    if (cornMask != 0x00ff)
        return -4;// missing corners
    sum = 0;
    for (int i=0; i<8; i++)
        sum += co[i];
    if (sum % 3 != 0)
        return -5;// twisted corner
    if (([Util getNParity:[Util getNPerm:ep n:12] n:12] ^ [Util getNParity:[self getCPerm] n:8]) != 0)
        return -6;// parity error
    return 0;// cube ok
}

// ******************** Initialization functions ********************

+(void) initMove {
    NSMutableArray *moveCube = [CubieCube moveCube];
    [moveCube replaceObjectAtIndex:0 withObject:[[CubieCube alloc] initCubie:15120 twist:0 eperm:119750400 flip:0]];
    [moveCube replaceObjectAtIndex:3 withObject:[[CubieCube alloc] initCubie:21021 twist:1494 eperm:323403417 flip:0]];
    [moveCube replaceObjectAtIndex:6 withObject:[[CubieCube alloc] initCubie:8064 twist:1236 eperm:29441808 flip:550]];
    [moveCube replaceObjectAtIndex:9 withObject:[[CubieCube alloc] initCubie:9 twist:0 eperm:5880 flip:0]];
    [moveCube replaceObjectAtIndex:12 withObject:[[CubieCube alloc] initCubie:1230 twist:412 eperm:2949660 flip:0]];
    [moveCube replaceObjectAtIndex:15 withObject:[[CubieCube alloc] initCubie:224 twist:137 eperm:328552 flip:137]];
    for (int a=0; a<18; a+=3) {
        for (int p=0; p<2; p++) {
            //[moveCube replaceObjectAtIndex:a+p+1 withObject:[[CubieCube alloc] init]]; //Likely cause for problems.
            [CubieCube EdgeMult:[moveCube objectAtIndex:(a+p)] cubeB:[moveCube objectAtIndex:a] cubeProd:[moveCube objectAtIndex:(a+p+1)]];
            [CubieCube CornMult:[moveCube objectAtIndex:(a+p)] cubeB:[moveCube objectAtIndex:a] cubeProd:[moveCube objectAtIndex:(a+p+1)]];
        }
    }
}

+ (void) initSym {
    CubieCube *c = [[CubieCube alloc] init];
    CubieCube *d = [[CubieCube alloc] init];
    CubieCube *t = nil;
    
    CubieCube *f2 = [[CubieCube alloc] initCubie:28783 twist:0 eperm:259268407 flip:0];
    CubieCube *u4 = [[CubieCube alloc] initCubie:15138 twist:0 eperm:119765538 flip:7];
    CubieCube *lr2 = [[CubieCube alloc] initCubie:5167 twist:0 eperm:83473207 flip:0];
    for (int x = 0; x < 8; x++) {
        lr2->co[x] = 3;
    }
    
    for (int i=0; i<16; i++) {
        CubieCube *newCube = [[CubieCube alloc] init];
        [newCube copyCubieCube:c];
        [[CubieCube CubeSym] replaceObjectAtIndex:i withObject:newCube];// Hopefully redundant rather than a big problem
        [CubieCube CornMult:c cubeB:u4 cubeProd:d];
        [CubieCube EdgeMult:c cubeB:u4 cubeProd:d];
        t = d;	d = c;	c = t;
        if (i % 4 == 3) {
            [CubieCube CornMult:c cubeB:lr2 cubeProd:d];
            [CubieCube EdgeMult:c cubeB:lr2 cubeProd:d];
            t = d;	d = c;	c = t;
        }
        if (i % 8 == 7) {
            [CubieCube CornMult:c cubeB:f2 cubeProd:d];
            [CubieCube EdgeMult:c cubeB:f2 cubeProd:d];
            t = d;	d = c;	c = t;
        }
    }
    for (int i=0; i<16; i++) {
        for (int j=0; j<16; j++) {
            [CubieCube CornMult:[[CubieCube CubeSym] objectAtIndex:i] cubeB:[[CubieCube CubeSym] objectAtIndex:j] cubeProd:c];
            for (int k=0; k<16; k++) {
                CubieCube* workingCube = [[CubieCube CubeSym] objectAtIndex:k];
                if (workingCube->cp[0] == c->cp[0] && workingCube->cp[1] == c->cp[1] && workingCube->cp[2] == c->cp[2]) { //Horribly inefficient
                    SymMult[i][j] = k;
                    if (k==0) {
                        SymInv[i] = j;
                    }
                    break;
                }
            }
        }
    }
    for (int j=0; j<18; j++) {
        for (int s=0; s<16; s++) {
            [CubieCube CornConjugate:[[CubieCube moveCube] objectAtIndex:j] idx:SymInv[s] cubeB:c];
            int m=0;
            int i=0;
        label: //Let this comment serve as a reminder of my pain while writing this.
            for (; m<18; m++) {
                for (i=0; i<8; i+=2) {
                    CubieCube *tempCube = [[CubieCube moveCube] objectAtIndex:m];
                    if (c->cp[i] != tempCube->cp[i]) {
                        //i++;
                        m++;
                        goto label;
                    }
                }
                SymMove[s][j] = m;
                break;
            }
        }
    }
    for (int j=0; j<10; j++) {
        for (int s=0; s<16; s++) {
            SymMoveUD[s][j] = std2ud[SymMove[s][ud2std[j]]];
        }
    }
    for (int j=0; j<8; j++) {
        for (int s=0; s<8; s++) {
            Sym8Mult[j][s] = SymMult[j<<1][s<<1]>>1;
            Sym8MultInv[j][s] = SymMult[j<<1][SymInv[s<<1]]>>1;
        }
    }
    for (int j=0; j<18; j++) {
        for (int s=0; s<8; s++) {
            Sym8Move[s][j] = SymMove[s<<1][j];
        }
    }
}

+(void) initFlipSym2Raw {
    CubieCube *c = [[CubieCube alloc] init];
    CubieCube *d = [[CubieCube alloc] init];
    int occ[2048 >> 5]; //Should be 64
    int count = 0;
    for (int i=0; i<64; occ[i++] = 0);
    //FlipR2S = malloc(2048*sizeof(int));
    for (int i=0; i<2048; i++) {
        if ((occ[i>>5]&(1<<(i&0x1f))) == 0) { //This shouldn't be called every time. << has been replaced with *2^
            [c setFlip:i];
            for (int s=0; s<16; s+=2) {
                [CubieCube EdgeConjugate:c idx:s cubeB:d];
                int idx = [d getFlip]; //idx isn't getting its correct value because d differs
                if (idx == i) {
                    SymStateFlip[count] |= 1 << (s >> 1);
                }
                occ[idx>>5] |= 1<<(idx&0x1f);
                FlipR2S[idx] = (count << 3) | (s >> 1);
            }
            FlipS2R[count++] = i;
        }
    }
}

+(void) initTwistSym2Raw {
    CubieCube *c = [[CubieCube alloc] init];
    CubieCube *d = [[CubieCube alloc] init];
    int occ[2187/32+1];
    int count = 0;
    for (int i=0; i<69; occ[i++] = 0);
    for (int i=0; i<2187; i++) {
        if ((occ[i>>5]&(1<<(i&0x1f))) == 0) {
            c.twist = i;
            for (int s=0; s<16; s+=2) {
                [CubieCube CornConjugate:c idx:s cubeB:d];
                int idx = [d getTwist];
                if (idx == i) {
                    SymStateTwist[count] |= 1 << (s >> 1);
                }
                occ[idx>>5] |= 1<<(idx&0x1f); //Problem point
                TwistR2S[idx] = (count << 3) | (s >> 1);
            }
            TwistS2R[count++] = i;
        }
    }
}

+(void) initPermSym2Raw {
    CubieCube *c = [[CubieCube alloc] init];
    CubieCube *d = [[CubieCube alloc] init];
    int occ[40320 / 32];
    int count = 0;
    for (int i=0; i<1260; occ[i++] = 0);
    //EPermR2S = malloc(40320*sizeof(int));
    for (int i=0; i<40320; i++) {
        if ((occ[i>>5]&(1<<(i&0x1f))) == 0) {
            [c setEPerm:i];
            for (int s=0; s<16; s++) {
                [CubieCube EdgeConjugate:c idx:s cubeB:d];
                int idx = [d getEPerm];
                if (idx == i) {
                    SymStatePerm[count] |= 1 << s;
                }
                occ[idx>>5] |= 1<<(idx&0x1f);
                int a = [d getU4Comb];
                int b = [d getD4Comb] >> 9;
                int m = 494 - (a & 0x1ff) + (a >> 9) * 70 + b * 1680;
                MtoEPerm[m] = EPermR2S[idx] = count << 4 | s;
            }
            EPermS2R[count++] = i;
        }
    }
}

@end
