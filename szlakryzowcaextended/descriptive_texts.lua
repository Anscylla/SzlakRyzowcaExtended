local description = require("szlakryzowcaextended.description")

local function setTextDescriptions(entry)
  description.setText(1, entry.text_description_line_01 or "")
  description.setText(2, entry.text_description_line_02 or "")
  description.setText(3, entry.text_description_line_03 or "")
  description.setText(4, entry.text_description_line_04 or "")
  description.setText(5, entry.text_description_line_05 or "")
  description.setText(6, entry.text_description_line_06 or "")
  description.setText(7, entry.text_description_line_07 or "")
  description.setText(8, entry.text_description_line_08 or "")
end

local function getTextDescriptions()
  return {
    description.getText(1),
    description.getText(2),
    description.getText(3),
    description.getText(4),
    description.getText(5),
    description.getText(6),
    description.getText(7),
    description.getText(8),
  }
end

return {
  setTextDescriptions = setTextDescriptions,
  getTextDescriptions = getTextDescriptions,
}