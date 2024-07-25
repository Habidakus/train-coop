extends Control

func set_stat(text: String, value: String) -> void:
	for child in $MarginContainer/StatList.get_children():
		var label : Label = child as Label
		if label != null && label.name == text:
			label.text = text + ": " + str(value)
			return
	var l = Label.new()
	l.name = text
	l.text = text + ": " + value
	$MarginContainer/StatList.add_child(l)
