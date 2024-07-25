extends Control

func set_stat(text: String, value: int) -> void:
	for child in $StatList.get_children():
		var label : Label = child as Label
		if label != null && label.name == text:
			label.text = text + ": " + str(value)
			return
	var l = Label.new()
	l.name = text
	l.text = text + ": " + str(value)
	$StatList.add_child(l)
