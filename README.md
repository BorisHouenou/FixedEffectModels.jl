[![Coverage Status](https://coveralls.io/repos/matthieugomez/FixedEffectModels.jl/badge.svg?branch=master)](https://coveralls.io/r/matthieugomez/FixedEffects.jl?branch=master)
[![Build Status](https://travis-ci.org/matthieugomez/FixedEffectModels.jl.svg?branch=master)](https://travis-ci.org/matthieugomez/FixedEffects.jl)

The function `reg` estimates linear models with high dimensional categorical variables. 

`reg` also computes robust standard errors (White or clustered). 
It is a basic and mostly untested implementation of the packages `reghdfe` in Stata and `lfe` in R.

## Fixed effects

Fixed effects must be variables of type PooledDataArray. Use the function `pool` to transform one column into a `PooledDataArray` and  `group` to combine multiple columns into a `PooledDataArray`.


```julia
df = dataset("plm", "Cigar")
df[:pState] =  pool(df[:pState])
df[:pState] =  pool(df[:pYear])
```

Add fixed effects with the option `absorb`

```julia
reg(Sales ~ NDI, df, absorb = [:pState])
# parenthesis when multiple fixed effects
reg(Sales ~ NDI, df, absorb = [:pState, :pYear]))
```

Add interactions with continuous variable using `&`

```julia
reg(Sales ~ NDI, absorb = [:pState, :pState&:Year])
```




## Errors

Compute robust standard errors using elements of type `AbstractVce`. For now, `VceSimple()` (default), `VceWhite()` and `VceCluster(cols)` are implemented.

```julia
reg(Sales ~ NDI, df,)
reg(Sales ~ NDI, df, VceWhite())
reg(Sales ~ NDI, df, VceCluster([:State]))
reg(Sales ~ NDI, df, VceCluster([:State, :Year]))
```


You can define your own type: After declaring it as a child of `AbstractVce`, define a `vcov` methods for it.

For instance,  White errors are implemented with the following code:

```julia
immutable type VceWhite <: AbstractVce 
end

function StatsBase.vcov(x::AbstractVceModel, t::VceWhite) 
	Xu = broadcast(*,  regressors(X), residuals(X))
	S = At_mul_B(Xu, Xu)
	scale!(S, nobs(X)/df_residual(X))
	sandwich(x, S) 
end
```

## Regression Result
`reg` returns a light object of type RegressionResult. It is only composed of coefficients, covariance matrix, and some scalars like number of observations, degrees of freedoms, etc. Usual methods  `coef`, `vcov`, `nobs`, `predict`, `residuals` are defined.




## Comparison

Julia
```julia
using DataArrays, DataFrames, FixedEffectModels
N = 10000000
K = 100
df = DataFrame(
  v1 =  pool(rand(1:N/K, N)),
  v2 =  pool(rand(1:K, N)),
  v3 =  randn(N), 
  v4 =  randn(N),
  w =  abs(randn(N)) 
)
@time reg(v4 ~ v3, df)
# elapsed time: 1.22074119 seconds (1061288240 bytes allocated, 22.01% gc time)
@time reg(v4 ~ v3, df, weight = :w)
# elapsed time: 1.56727235 seconds (1240040272 bytes allocated, 15.59% gc time)
@time reg(v4 ~ v3, df, absorb = [:v1])
# elapsed time: 1.563452151 seconds (1269846952 bytes allocated, 17.99% gc time)
@time reg(v4 ~ v3, df, absorb = [:v1], weight = :w)
# elapsed time: 2.063922289 seconds (1448598696 bytes allocated, 17.96% gc time)
@time reg(v4 ~ v3, df, absorb = [:v1, :v2])
# elapsed time: 2.494780022 seconds (1283607248 bytes allocated, 18.87% gc time)
````

R (lfe package, C)
```R
library(lfe)
N = 10000000
K = 100
df = data.frame(
  v1 =  as.factor(sample(N/K, N, replace = TRUE)),
  v2 =  as.factor(sample(K, N, replace = TRUE)),
  v3 =  runif(N), 
  v4 =  runif(N), 
  w = abs(runif(N))
)
system.time(lm(v4 ~ v3, df))
#   user  system elapsed 
# 15.712   0.811  16.448 
system.time(lm(v4 ~ v3, df, w = w))
#   user  system elapsed 
# 10.416   0.995  11.474 
system.time(felm(v4 ~ v3|v1, df))
#   user  system elapsed 
# 19.971   1.595  22.112 
system.time(felm(v4 ~ v3|v1, df))
#   user  system elapsed 
# 19.971   1.595  22.112 
system.time(felm(v4 ~ v3|v1, df, w = w))
#   user  system elapsed 
# 19.971   1.595  22.112 
system.time(felm(v4 ~ v3|(v1+v2), df))
#   user  system elapsed 
# 23.980   1.950  24.942 
```



Stata
```
clear all
local N = 10000000
local K = 100
set obs `N'
gen  v1 =  floor(runiform() * (`_N'+1)/`K')
gen  v2 =  floor(runiform() * (`K'+1))
gen  v3 =  runiform()
gen  v4 =  runiform()
gen  w =  abs(runiform()) 

timer clear

timer on 1
reg v4 v3
timer off 1

timer on 2
reg v4 v3 [w = w]
timer off 2

timer on 3
areg v4 v3, a(v1)
timer off 3

timer on 4
areg v4 v3 [w = w], a(v1)
timer off 4

timer on 5
reghdfe v4 v3, a(v1 v2)
timer off 5

. . timer list
   1:      1.61 /        1 =       1.4270
   2:      1.95 /        2 =       1.9510
   2:      5.04 /        1 =       5.0380
   3:      5.45 /        1 =       5.4530
   4:     67.24 /        1 =      67.2430
````



