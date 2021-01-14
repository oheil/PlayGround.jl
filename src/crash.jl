
using GeneralizedGenerated

binary_operators=[
    :(+),
    :(*),
    :(-),
    :(/),
    :(^),
]
unary_operators=[
    :(sin),
    :(cos),
    :(tan),
]

function get_unary_operator()
    return rand(unary_operators)
end
function get_binary_operator()
    return rand(binary_operators)
end

function create_expression( x::Symbol, p::Symbol, depth=0, pcount=1 )
    expr1=x
    if rand(0:depth)>0
        (expr1,pcount)=create_expression( x, p, depth-1, pcount )
    end
	expr2=:( p[$pcount] )
    if rand(0:depth) == 0
        pcount+=1
    else
        (expr2,pcount)=create_expression( x, p, depth-1, pcount )
    end
	expr=expr1
	if rand(1:2)==1
		op=get_unary_operator()
		expr=Expr( :call, op, expr)
	end
	op=get_binary_operator()
	expr=Expr( :call, op, expr, expr2)
    return expr,pcount
end

function crash()
	step=1
	exception_count=0
	nan_count=0
	θ = π/2
	p = [1,2]
	while true
		(e,pcount) = create_expression( :θ, :p, 1)
		f = mk_function( :( (θ,p) -> $e ) )
		try
			new_θ=f(θ,p)
			println(step," ",exception_count," ",nan_count," : ",e," ",p," ",θ,"->",new_θ)
			if isnan(new_θ)
				nan_count+=1
			end
		catch e
			println(step," ",e)
			exception_count+=1
		end
		step+=1
	end
end

crash()

