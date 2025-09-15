extends Node

# Test script to verify circular buffer logic for performance tracker
const DEBUG_LOGGING = true

func _ready():
	print("=== TESTING CIRCULAR BUFFER LOGIC ===")
	test_circular_buffer_calculation()

func test_circular_buffer_calculation():
	print("Testing circular buffer calculation (1-30):")
	
	# Test various max_index values to ensure proper circular behavior
	var test_cases = [0, 1, 5, 15, 29, 30, 31, 45, 60, 90]
	
	for current_index in test_cases:
		var next_index = (current_index % 30) + 1
		var data_id = "performance_" + str(next_index)
		print("current_index: %d -> next_index: %d -> file: %s" % [current_index, next_index, data_id])
	
	print("\nVerifying that we cycle through 1-30:")
	print("Starting from index 0:")
	var current = 0
	for i in range(35):  # Test 35 iterations to see the cycling
		var next = (current % 30) + 1
		var file_name = "performance_" + str(next)
		print("Iteration %d: index %d -> file %s" % [i + 1, next, file_name])
		current = next
	
	print("=== CIRCULAR BUFFER TEST COMPLETE ===")
	print("The system should cycle: 1,2,3...29,30,1,2,3...29,30,1...")