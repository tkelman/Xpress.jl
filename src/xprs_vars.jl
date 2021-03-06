# Variables in Xpress model

# variable kinds


function fixInf(val::Float64)
    if val == Inf
        return XPRS_PLUSINFINITY
    elseif val == -Inf
        return XPRS_MINUSINFINITY
    else
        return val
    end
end
function fixInfs!(vals::Vector{Float64})
    for i in eachindex(vals)
        vals[i] = fixInf(vals[i])
    end
end

# add_var! single var
function add_var!(model::Model, newnz::Int, mrwind::Vector{Int},dmatval::Vector{Float64}, objx::Float64, lb::Float64, ub::Float64)
    lb = fixInf(lb)
    ub = fixInf(ub)

    ret = @xprs_ccall(addcols, Cint, (
        Ptr{Void},    # model
        Cint,         # number of new cols
        Cint,         # number of nonzeros in added cols
        Ptr{Float64}, # coefs in objective
        Ptr{Cint},     # mstart ????
        Ptr{Cint},     # mrwind: row indexes of each col
        Ptr{Float64},      # elemnts values
        Ptr{Float64},      # lb
        Ptr{Float64}    # ub
        ),
        model.ptr_model, 1, newnz, fvec(objx), ivec(0), ivec(mrwind)-1, fvec(dmatval), fvec(lb), fvec(ub))

    if ret != 0
        throw(XpressError(model))
    end
    nothing
end

function chgcoltype!(model::Model, colnum::Int, vtype::Cchar)
    ret = @xprs_ccall(chgcoltype,Cint,(Ptr{Void},Cint,Ptr{Cint},Ptr{Cchar}),
        model.ptr_model,1,Cint[colnum-1],Cchar[vtype])
    if  0 != ret
        throw(XpressError(model))
    end
end


function chgcoltypes!(model::Model, colnums::Vector{Int}, vtypes::Vector{Cchar})

    n=length(colnums)
    ret = @xprs_ccall(chgcoltype,Cint,(
        Ptr{Void},
        Cint,
        Ptr{Cint},
        Ptr{Cchar}),
        model.ptr_model, n, ivec(colnums-1), vtypes )
    if 0 != ret
        throw(XpressError(model))
    end
end

function chgsemilb!(model::Model, colnums::Vector{Int}, lb::Vector)
#int XPRS_CC XPRSchgglblimit(XPRSprob prob, int ncols, const int mindex[], const double dlimit[]);

    n=length(colnums)
    ret = @xprs_ccall(chgglblimit,Cint,(
        Ptr{Void},
        Cint,
        Ptr{Cint},
        Ptr{Float64}),
        model.ptr_model, n, ivec(colnums-1), lb )
    if 0 != ret
        throw(XpressError(model))
    end

end

#only add in obj
function add_var!(model::Model, vtype::Cchar, c::Float64, lb::Float64, ub::Float64)
    lb = fixInf(lb)
    ub = fixInf(ub)

    ret = @xprs_ccall(addcols, Cint, (
        Ptr{Void},    # model
        Cint,         # number of new cols
        Cint,         # number of nonzeros in added cols
        Ptr{Float64}, # coefs in objective
        Ptr{Cint},     # mstart ????
        Ptr{Cint},     # mrwind: row indexes of each col
        Ptr{Float64},      # elemnts values
        Ptr{Float64},      # lb
        Ptr{Float64}    # ub
        ),
        model.ptr_model, 1, 0, fvec(c), ivec(0), C_NULL, C_NULL, fvec(lb), fvec(ub))
    if ret != 0
        throw(XpressError(model))
    end

    if vtype == XPRS_INTEGER
        chgcoltype!(model, get_intattr(model,XPRS_COLS), XPRS_INTEGER)
    elseif vtype ==XPRS_BINARY
        chgcoltype!(model, get_intattr(model,XPRS_COLS), XPRS_BINARY)
    end

    nothing
end


function add_var!(model::Model, vtype::GChars, c::Real, lb::Real, ub::Real)
    add_var!(model, cchar(vtype), Float64(c), Float64(lb), Float64(ub))
end
add_var!(model::Model, vtype::GChars, c::Real) = add_var!(model, vtype, c, XPRS_MINUSINFINITY, XPRS_PLUSINFINITY)

add_cvar!(model::Model, c::Real, lb::Real, ub::Real) = add_var!(model, XPRS_CONTINUOUS, c, lb, ub)
add_cvar!(model::Model, c::Real) = add_cvar!(model, c, XPRS_MINUSINFINITY, XPRS_PLUSINFINITY)

add_bvar!(model::Model, c::Real) = add_var!(model, XPRS_BINARY, c, 0., 1.)

add_ivar!(model::Model, c::Real, lb::Real, ub::Real) = add_var!(model, XPRS_INTEGER, c, lb, ub)
add_ivar!(model::Model, c::Real) = add_ivar!(model, c, XPRS_MINUSINFINITY, XPRS_PLUSINFINITY)


# add_vars!
#multiple variables at once
function add_vars!(model::Model, vtypes::CVec, c::FVec, lb::FVec, ub::FVec)

    # check dimensions
    n = length(vtypes)
    _chklen(c, n)
    _chklen(lb, n)
    _chklen(ub, n)

    fixInfs!(lb)
    fixInfs!(ub)

    prev_cols = get_intattr(model,XPRS_COLS)
    # main call
    ret = @xprs_ccall(addcols, Cint, (
        Ptr{Void},    # model
        Cint,         # number of new cols
        Cint,         # number of nonzeros in added cols
        Ptr{Float64}, # coefs in objective
        Ptr{Cint},     # mstart ????
        Ptr{Cint},     # mrwind: row indexes of each col
        Ptr{Float64},      # elemnts values
        Ptr{Float64},      # lb
        Ptr{Float64}    # ub
        ),
        model.ptr_model, n, 0, c, ivec( collect(0:(n-1)) ), C_NULL, C_NULL, lb, ub)
                                #check
    if ret != 0
        throw(XpressError(model))
    end

    #vtypes = cvecx(vtypes, n)
    for i in 1:n
        if vtypes[i] == XPRS_INTEGER
            chgcoltype!(model,prev_cols+i,XPRS_INTEGER)
        elseif vtypes[i] ==XPRS_BINARY
            chgcoltype!(model,prev_cols+i,XPRS_BINARY)
        end
    end
    nothing
end

function add_vars!(model::Model, vtypes::GCharOrVec, c::Vector, lb::Bounds, ub::Bounds)
    n = length(c)
    add_vars!(model, cvecx(vtypes, n), fvec(c), fvecx(lb, n), fvecx(ub, n))
end

add_cvars!(model::Model, c::Vector, lb::Bounds, ub::Bounds) = add_vars!(model, XPRS_CONTINUOUS, c, lb, ub)
add_cvars!(model::Model, c::Vector) = add_cvars!(model, c, XPRS_MINUSINFINITY, XPRS_PLUSINFINITY)

add_bvars!(model::Model, c::Vector) = add_vars!(model, XPRS_BINARY, c, 0, 1)

add_ivars!(model::Model, c::Vector, lb::Bounds, ub::Bounds) = add_vars!(model, XPRS_INTEGER, c, lb, ub)
add_ivars!(model::Model, c::Vector) = add_ivars!(model, XPRS_INTEGER, c, XPRS_MINUSINFINITY, XPRS_PLUSINFINITY) #


del_vars!{T<:Real}(model::Model, idx::T) = del_vars!(model, Cint[idx])
del_vars!{T<:Real}(model::Model, idx::Vector{T}) = del_vars!(model, convert(Vector{Cint},idx))
function del_vars!(model::Model, idx::Vector{Cint})
    numdel = length(idx)
    ret = @xprs_ccall(delcols, Cint, (
                     Ptr{Void},
                     Cint,
                     Ptr{Cint}),
                     model, convert(Cint,numdel), idx-Cint(1))
    if ret != 0
        throw(XpressError(model))
    end
end 