# message types:
# TO_HUB
# 1 => server update or timeout reply
# 2 => server closed
# 3 => list request
# 4 => server creation request
# 5 => server created
# FROM_HUB
# 1 server list message
# 2 timeout request
# 3 server approval
# 4 server disapproval
# 5 server added

extends Node
var server_list = {}
var server_ttl = {}
var list:PoolByteArray
var socketUDP = PacketPeerUDP.new()
const PORT_HUB=6745
const PORT_CLIENT=6744
onready var itemlist = get_node("ItemList")
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	start_server()
	add_server("255.255.255.255","test",1)
	add_server("192.168.1.1","test2",1)

func add_server(ip:String,name:String,num)->bool:
	if server_list.has(name):
		return false
	server_list[name]=[ip,num]
	server_ttl[name]=true
	append_list(name,[ip,num])
	itemListUpdate()
	return true

func remove_server(name:String)->void:
	server_list.erase(name)	
	server_ttl.erase(name)
	itemListUpdate()
	build_list()

func modify_num(ip:String,name:String,num)->void:
	if server_list.has(name):
		if server_list[name][1]!=num:
			server_list[name][1]=num
			build_list()
		server_ttl[name]=true
	else:
# warning-ignore:return_value_discarded
		add_server(ip,name,num)


func _on_Timer_timeout() -> void:
	print("timeout")
	for server in server_list.keys():
		request_update(server_list[server][0])
		if server_ttl[server]==false:
			remove_server(server)
		else:
			server_ttl[server]=false
		itemListUpdate()

func request_update(ip:String)->void:
	socketUDP.set_dest_address(ip, PORT_CLIENT)
	var pac = PoolByteArray()
	pac.append(2)
	socketUDP.put_packet(pac)

func start_server():
	if (socketUDP.listen(PORT_HUB) != OK):
		printt("Error listening on port: " + str(PORT_HUB))
	else:
		printt("Listening on port: " + str(PORT_HUB))

func _exit_tree():
	socketUDP.close()

#packet structure: [0]=type
func _process(_delta):
	while socketUDP.get_available_packet_count()>0:
		var raw = socketUDP.get_packet()
		print("got paquet of type "+str(raw[0]))
		match raw[0]:
			1: # name + num
				var name = (raw.subarray(2,1+raw[1])).get_string_from_ascii()
				var num=raw[2+raw[1]]
				var ip = socketUDP.get_packet_ip()
				modify_num(ip,name,num)
			2: #close
				var name = (raw.subarray(2,1+raw[1])).get_string_from_ascii()
				remove_server(name)
			3: #ask list
				var ip = socketUDP.get_packet_ip()
				socketUDP.set_dest_address(ip, PORT_CLIENT)
				print("sending list to "+ip+" "+str(PORT_CLIENT))
				var paquet = PoolByteArray()
				paquet.append(1)
				paquet.append_array(list)
				paquet.append(70)
				socketUDP.put_packet(paquet)
			4: #ask if server name valid
				var name =  (raw.subarray(2,1+raw[1])).get_string_from_ascii()
				var paquet = PoolByteArray()
				var ip = socketUDP.get_packet_ip()
				socketUDP.set_dest_address(ip, PORT_CLIENT)
				if server_list.has(name):
					paquet.append(4)
				else:
					paquet.append(3)
				socketUDP.put_packet(paquet)
			5: #server created
				var name = (raw.subarray(2,1+raw[1])).get_string_from_ascii()
				var num=raw[2+raw[1]]
				var ip = socketUDP.get_packet_ip()
				var paquet = PoolByteArray()
				if server_list.has(name):
					paquet.append(3)
				else:
					paquet.append(5)
				socketUDP.put_packet(paquet)
				add_server(ip,name,num)

func build_list()->void:
	list= PoolByteArray()
	for server in server_list.keys():
		append_list(server,server_list[server])

func append_list(name:String,params:Array)->void:
	var Bname=name.to_ascii()
	list.append(Bname.size())
	list.append_array(Bname)
	var ip = params[0].to_ascii()
	list.append(ip.size())
	list.append_array(ip)
	list.append(params[1])

func itemListUpdate()->void:
	itemlist.clear()
	for server in server_list.keys():
		itemlist.add_item("["+str(server_list[server][1])+"] "+server,null,false)
