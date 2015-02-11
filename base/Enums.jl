module Enums

export @enum

abstract Enum

function Base.convert{T<:Integer}(::Type{T},x::Enum)
    (x.n < typemin(T) || x.n > typemax(T)) && throw(InexactError())
    convert(T, x.n)
end
Base.convert(::Type{BigInt},x::Enum) = big(x.n)
function Base.convert{T<:Enum}(::Type{T},x::Integer)
    (x < typemin(T).n || x > typemax(T).n) && throw(InexactError())
    T(x)
end
Base.start{T<:Enum}(::Type{T}) = 1
Base.next{T<:Enum}(::Type{T},s) = Base.next(names(T),s)
Base.done{T<:Enum}(::Type{T},s) = Base.done(names(T),s)
# Pass Integer through to Enum constructor through Val{T}
call{T<:Enum}(::Type{T},x::Integer) = T(Val{convert(fieldtype(T,:n),x)})
# Catchall that errors when specific Enum(::Type{Val{n}}) hasn't been defined
call{T<:Enum,n}(::Type{T},::Type{Val{n}}) = error(string("invalid enum value for $T: ",n))

macro enum(T,syms...)
    assert(!isempty(syms))
    vals = Array((Symbol,Integer),0)
    lo = typemax(Int)
    hi = typemin(Int)
    i = -1
    enumT = typeof(i)
    for s in syms
        i += one(typeof(i))
        if isa(s,Symbol)
            # pass
        elseif isa(s,Expr) && s.head == :(=) && length(s.args) == 2 && isa(s.args[1],Symbol)
            i = eval(s.args[2]) # allow exprs, e.g. uint128"1"
            s = s.args[1]
        else
            error(string("invalid syntax in @enum: ",s))
        end
        push!(vals, (s,i))
        I = typeof(i)
        enumT = ifelse(length(vals) == 1, I, promote_type(enumT,I))
        i < lo && (lo = i)
        i > hi && (hi = i)
    end
    blk = quote
        # enum definition
        immutable $(esc(T)) <: $(esc(Enum))
            n::$(esc(enumT))
        end
        $(esc(:(Base.typemin)))(x::Type{$(esc(T))}) = $(esc(T))($lo)
        $(esc(:(Base.typemax)))(x::Type{$(esc(T))}) = $(esc(T))($hi)
        $(esc(:(Base.length)))(x::Type{$(esc(T))}) = $(length(vals))
        $(esc(:(Base.names)))(x::Type{$(esc(T))}) = $(esc(T))[]
        function $(esc(:(Base.show))){T<:$(esc(T))}(io::IO,x::T)
            vals = $vals
            for (sym, i) in vals
                i = convert($(esc(enumT)), i)
                i == x.n && print(io, sym)
            end
            print(io, "::", T.name)
        end
    end
    for (sym,i) in vals
        i = convert(enumT, i)
        # add inner constructors to Enum type definition for specific Val{T} values
        push!(blk.args[2].args[3].args, :($(esc(T))(::Type{Val{$i}}) = new($i)))
        # define enum member constants
        push!(blk.args, :(const $(esc(sym)) = $(esc(T))($i)))
        # add enum member value to names(T) function
        push!(blk.args[10].args[2].args[2].args, :($(esc(sym))))
    end
    push!(blk.args, :nothing)
    blk.head = :toplevel
    return blk
end

end # module
