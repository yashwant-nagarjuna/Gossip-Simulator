<h2 align = "center">  COP5615:    DISTRIBUTED OPERATING SYSTEMS </h2>
<h2 align = "center" > Project-2 </h2>

<p> <b>Submitted by: </b> <br/>
Student Name: Yashwant Nagarjuna Kuppa UFID: 7181-4301 <br/>
Student Name: Mokal Pranav UFID: 6812-1781<br/>
No. of Group member(s): 2 <br/> </p>

## What is working? 
<!-- *full network*: the algorithm converged for any number of nodes, since they are all connected.
*3D grid*: 
*Random 2D grid*:
*Torus*:
*Line*:
*Imperfect line*  -->
**Gossip** and **Push-sum** works on all topologies with the exception of number of nodes to be greater than 300 for **Random 2D Grid**. Since, there is a possibility of a node not having a neighbour, and hence it prevents convergence.


## What is the largest network you managed to deal with for each type of topology and algorithm
### For Gossip algorithm: 
Full network: 9000 nodes<br>
Line: 5000 nodes<br>
Imperfect line: 6000 nodes<br>
random 2D grid: 3000 nodes<br>
Torus: 25000 nodes<br>
3D: 25000 nodes<br>

### For Push sum algorithm
Full network: 5000 nodes<br>
Line: 600 nodes<br>
Imperfect line: 10000 nodes<br>
Random 2D grid: 5000 nodes<br>
Torus: 5000 nodes<br>
3D: 10000 nodes<br>

```elixir
mix run project2.ex numNodes topology algorithm
```
Input:<br>
**numNodes** -> Number of nodes in the network<br>
**topology** -> full, line, 3D, torus, imp2D, rand2D<br>
**algorithm** -> gossip, push-sum<br>

Output:<br>
Convergence time in *microseconds*.<br>



