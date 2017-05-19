using DataFrames, FixedEffectModels, GLM, Base.Test

df = readtable(joinpath(dirname(@__FILE__), "..", "dataset/Cigar.csv.gz"))
df[:pState] = pool(df[:State])
df[:pYear] = pool(df[:Year])


function glm_helper(formula::Formula, df::DataFrame) 
    model_response(ModelFrame(formula, df)) - predict(glm(formula, df, Normal(), IdentityLink()))
end
function glm_helper(formula::Formula, df::DataFrame, wts::Symbol) 
    model_response(ModelFrame(formula, df)) - predict(glm(formula, df, Normal(), IdentityLink(), wts = convert(Array{Float64}, df[wts])))
end

test = (
    convert(Array{Float64}, partial_out(df, @model(Sales + Price ~ NDI))),
    convert(Array{Float64}, partial_out(df, @model(Sales + Price ~ NDI, fe = pState))),
    convert(Array{Float64}, partial_out(df, @model(Sales + Price ~ 1, fe = pState))),
    convert(Array{Float64}, partial_out(df, @model(Sales + Price ~ 1))),
    mean(convert(Array{Float64}, partial_out(df, @model(Sales + Price ~ NDI, add_mean = true))), 1),
    mean(convert(Array{Float64}, partial_out(df, @model(Sales + Price ~ NDI, fe = pState, add_mean = true))), 1),
    mean(convert(Array{Float64}, partial_out(df, @model(Sales + Price ~ 1, fe = pState, add_mean = true))), 1),
    mean(convert(Array{Float64}, partial_out(df, @model(Sales + Price ~ 1, add_mean = true))), 1),
    convert(Array{Float64}, partial_out(df, @model(Sales + Price ~ NDI, weights = Pop))),
    convert(Array{Float64}, partial_out(df, @model(Sales + Price ~ NDI, fe = pState, weights = Pop))),
    convert(Array{Float64}, partial_out(df, @model(Sales + Price ~ 1, fe = pState, weights = Pop))),
    convert(Array{Float64}, partial_out(df, @model(Sales + Price ~ 1, weights = Pop))),
    )

answer = (
    hcat(glm_helper(@formula(Sales ~ NDI), df), glm_helper(@formula(Price ~ NDI), df)),
    hcat(glm_helper(@formula(Sales ~ NDI + pState), df), glm_helper(@formula(Price ~ NDI + pState), df)),
    hcat(glm_helper(@formula(Sales ~ pState), df), glm_helper(@formula(Price ~ pState), df)),
    hcat(glm_helper(@formula(Sales ~ 1), df), glm_helper(@formula(Price ~ 1), df)),
    hcat(mean(df[:Sales]), mean(df[:Price])),
    hcat(mean(df[:Sales]), mean(df[:Price])),
    hcat(mean(df[:Sales]), mean(df[:Price])),
    hcat(mean(df[:Sales]), mean(df[:Price])),
    hcat(glm_helper(@formula(Sales ~ NDI), df, :Pop), glm_helper(@formula(Price ~ NDI), df, :Pop)),
    hcat(glm_helper(@formula(Sales ~ NDI + pState), df, :Pop), glm_helper(@formula(Price ~ NDI + pState), df, :Pop)),
    hcat(glm_helper(@formula(Sales ~ pState), df, :Pop), glm_helper(@formula(Price ~ pState), df, :Pop)),
    hcat(glm_helper(@formula(Sales ~ 1), df, :Pop), glm_helper(@formula(Price ~ 1), df, :Pop))
    )

for i in 1:12
    @test test[i] ≈ answer[i] atol = 1e-5
end


df[1, :Sales] = NA
df[2, :Price]  = NA
df[5, :Pop]  = NA
df[6, :Pop]  = -1.0
partial_out(df, @model(Sales + Price ~ 1, weights = Pop))