-- pandoc Lua filter: turn Unicode subscript digits into LaTeX math subscripts.
-- Needed because the CJK fonts used for the PDF lack U+2080-U+2089.
local map = {
  ["₀"] = "0", ["₁"] = "1", ["₂"] = "2", ["₃"] = "3", ["₄"] = "4",
  ["₅"] = "5", ["₆"] = "6", ["₇"] = "7", ["₈"] = "8", ["₉"] = "9",
}

function Str(el)
  local s = el.text
  local hit = false
  for ch in pairs(map) do
    if s:find(ch, 1, true) then hit = true; break end
  end
  if not hit then return nil end

  local out = pandoc.List()
  local buf = ""
  for _, code in utf8.codes(s) do
    local ch = utf8.char(code)
    if map[ch] then
      if buf ~= "" then out:insert(pandoc.Str(buf)); buf = "" end
      out:insert(pandoc.RawInline("latex", "$_{" .. map[ch] .. "}$"))
    else
      buf = buf .. ch
    end
  end
  if buf ~= "" then out:insert(pandoc.Str(buf)) end
  return out
end
