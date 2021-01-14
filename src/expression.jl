
@enum OperatorType begin
    unary
    binary
end

struct Operator
    op::Symbol
    type::OperatorType
end

unary_operators=[
    Operator(:(sin),unary),
    Operator(:(cos),unary),
    Operator(:(tan),unary),
]
binary_operators=[
    Operator(:(+),binary),
    Operator(:(*),binary),
    Operator(:(-),binary),
    Operator(:(/),binary),
    Operator(:(^),binary),
]
all_operators=reduce(vcat,[
    unary_operators,
    binary_operators
])

function get_operator()
    return rand(all_operators)
end
function get_binary_operator()
    return rand(binary_operators)
end

function create_expression( x::Symbol, p::Symbol, depth=0, pcount=1 )
	expr1=x
    #expr2=Meta.parse(string(p)*"["*string(pcount)*"]")
    expr2=:( p[$pcount] )
	pcount+=1
    op=get_operator()
    if op.type == unary
        expr=Expr( :call, get_binary_operator().op, Expr( :call, op.op, expr1), expr2)
    elseif op.type == binary
        expr=Expr( :call, op.op, expr1, expr2)
	end
	depth-=1
	while depth>=0
        expr1=x
        expr2=:( p[$pcount] )
		op=get_operator()
		pcount+=1
		if op.type == unary
			expr3=Expr( :call, get_binary_operator().op, Expr( :call, op.op, expr1), expr2)
		elseif op.type == binary
			expr3=Expr( :call, op.op, expr1, expr2)
        end
        op=get_binary_operator()
        expr=Expr( :call, op.op, expr, expr3)
		depth-=1
	end
    return expr,pcount
end

