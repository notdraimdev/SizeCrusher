extends Control

@onready var to_convert_list: ItemList = $HBoxContainer/Left/ToConvertList
@onready var file_type_selector: MenuButton = $HBoxContainer/Right/VBoxContainer/FileTypeSelector
@onready var explanation_text: RichTextLabel = $HBoxContainer/Right/VBoxContainer/ExplanationText
@onready var max_size_edit: LineEdit = $HBoxContainer/Right/VBoxContainer/BitRateContainer/MaxSizeEdit
@onready var converting_showcaser: Label = $ConvertingShowcaser

var FiletypeDefinition:Dictionary = {"video":["mp4","mkv","webm"],"audio":["mp3","ogg","wav"],"image":["png","jpg","jpeg"]}

var CurrentlySelectedFile:String
var CurrentFiletype:String = "none"


var _is_setup: bool = false


#region SadRegion
const ffmpeg_sources: Dictionary = {
	"ffmpeg": "https://github.com/Nolkaloid/godot-youtube-dl/releases/latest/download/ffmpeg.exe",
	"ffprobe": "https://github.com/Nolkaloid/godot-youtube-dl/releases/latest/download/ffprobe.exe",
}
const Downloader = preload("res://Downloader.gd")
var _downloader: Downloader
func is_setup() -> bool:
	return _is_setup

func FilesMissing() -> bool:
	var executable_name: String = "yt-dlp.exe" if OS.get_name() == "Windows" else "yt-dlp"
	
	if OS.get_name() == "Windows":
		if not FileAccess.file_exists("user://%s" % executable_name):
			return true
		if not FileAccess.file_exists("user://ffmpeg.exe"):
			return true
		if not FileAccess.file_exists("user://ffprobe.exe"):
			return true
	elif OS.get_name() == "Linux":
		var stuff = OS.execute("bash",PackedStringArray(["-c","ffprobe"]))
		print(stuff)
		print(OS.get_distribution_name())
		if stuff != 1:
			return true
		var stuff2 = OS.execute("bash",PackedStringArray(["-c","ffmpeg"]))
		print(stuff2)
		if stuff2 != 1:
			return true
	return false

func setup() -> void:
	_setup_ffmpeg()
	
	_is_setup = true


func _setup_ffmpeg() -> void:
	if not FileAccess.file_exists("user://ffmpeg.exe"):
		if OS.get_name() == "Windows":
			_downloader.download(ffmpeg_sources["ffmpeg"], "user://ffmpeg.exe")
			await _downloader.download_completed
			print(OS.get_distribution_name())
		elif OS.get_distribution_name() in ["Ubuntu","Linux Mint","Debian"]:
			var stuff = OS.execute("bash",PackedStringArray(["-c","ffmpeg"]))
			print(stuff)
			print("a")
			if stuff !=1:
				push_error("FFMPEG NOT INSTALLED")
			print(OS.get_distribution_name())
		else:
			print(OS.get_distribution_name())
	
	if not FileAccess.file_exists("user://ffprobe.exe"):
		if OS.get_name() == "Windows":
			_downloader.download(ffmpeg_sources["ffprobe"], "user://ffprobe.exe")
			print(OS.get_distribution_name())
			await _downloader.download_completed
		elif OS.get_name() == "Linux":
			var stuff = OS.execute("bash",PackedStringArray(["-c","ffprobe"]))
			print(stuff)
			if stuff != 1:
				push_error("FFPROBE NOT INSTALLED")
			print(OS.get_distribution_name())
		else:
			print(OS.get_distribution_name())


#endregion


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if FilesMissing():
		setup()
	get_window().files_dropped.connect(FilesDropped)
	file_type_selector.get_popup().index_pressed.connect(FiletypeSelected)

func FiletypeSelected(idx:int):
	CurrentFiletype = file_type_selector.get_popup().get_item_text(idx)
	UpdateExplanationText()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass # Replace with function body.

func FilesDropped(files):
	print(files)
	for file in files:
		to_convert_list.add_item(file)
		CurrentlySelectedFile = file

func _on_convert_button_pressed() -> void:
	var fileTemp = CurrentlySelectedFile.split("/",false)
	var file:String
	for part in fileTemp.size()-1:
		file += "/" + fileTemp[part]
	file += "/"
	file += fileTemp[-1].split(".")[0] +"."+ CurrentFiletype
	var s = ConvertFile(CurrentlySelectedFile,file)
	CopyToClipboard(file)
	if s:
		pass	

func _on_clip_board_button_pressed() -> void:
	var file = "user://tempvid." + CurrentFiletype
	var s = ConvertFile(CurrentlySelectedFile,file)
	CopyToClipboard(file)
	if s:
		pass	

func CopyToClipboard(file):
	var Fileacces:FileAccess = FileAccess.open(file,FileAccess.READ)
	print(Fileacces.get_open_error())
	print(file)
	#DisplayServer.clipboard_set(str(Fileacces.g))

func _on_to_convert_list_item_selected(index: int) -> void:
	CurrentlySelectedFile = to_convert_list.get_item_text(index)
	print("selected: ",to_convert_list.get_item_text(index))
	file_type_selector.get_popup().clear()
	
	var ToConvertToTypes:Array = []
	
	if ArrayInArray(FiletypeDefinition["video"], CurrentlySelectedFile.split(".")):
		ToConvertToTypes = ["video","audio"]
	elif ArrayInArray(FiletypeDefinition["audio"], CurrentlySelectedFile.split(".")):
		ToConvertToTypes = ["audio"]
	elif ArrayInArray(FiletypeDefinition["image"], CurrentlySelectedFile.split(".")):
		ToConvertToTypes = ["image"]
	if !ToConvertToTypes.is_empty():
		for Type in ToConvertToTypes:
			for extention in FiletypeDefinition[Type]:
				file_type_selector.get_popup().add_item(extention)
	
## If CheckArr has something of inputArr inside it it returns true, else false
func ArrayInArray(inputArr:Array,CheckArr:Array) -> bool:
	for check in CheckArr:
		print(check,"  ",inputArr)
		if check in inputArr:
			print("yay")
			return true
	return false



func UpdateExplanationText():
	explanation_text.text = "[color=green]" + str(CurrentlySelectedFile.split("/")[-1]) + "[/color] will be converted to [color=light_blue]" + CurrentFiletype + "[/color]"

## returns its sucess
func ConvertFile(File:String,SaveToPath:String):
	var thread:Thread = Thread.new()
	converting_showcaser.show()
	thread.start(ConvertFileClipboard.bind(File,SaveToPath))
	thread.wait_to_finish()
	converting_showcaser.hide()

func ConvertFileClipboard(File:String,SaveToPath:String) -> bool:
	var args:PackedStringArray = PackedStringArray(["ffmpeg"])
	args.append_array(["-i",'"' + (File) + '"','"' + (ProjectSettings.globalize_path(SaveToPath)) + '"'])
	var output:Array
	var NewString:StringName
	for thing in args:
		NewString += thing.replace("\\","") + " "
	var result = OS.execute("bash",PackedStringArray(["-c",NewString.replace("\\","")]),output,false,true)
	print(PackedStringArray(["-c",str(NewString)]))
	print(result,"    aww")
	if result == 0:
		return true
	return false


func _on_max_size_edit_text_submitted(new_text: String) -> void:
	pass # Replace with function body.
