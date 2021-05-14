tga_encoder = {}

local image = setmetatable({}, {
	__call = function(self, ...)
		local t = setmetatable({}, {__index = self})
		t:constructor(...)
		return t
	end,
})

function image:constructor(pixels)
	self.data = ""
	self.pixels = pixels
	self.width = #pixels[1]
	self.height = #pixels

	self:encode()
end

function image:encode_colormap_spec()
	self.data = self.data
		.. string.char(0, 0) -- first entry index
		.. string.char(0, 0) -- number of entries
		.. string.char(0) -- bits per pixel
end

function image:encode_image_spec()
	self.data = self.data
		.. string.char(0, 0) -- X-origin
		.. string.char(0, 0) -- Y-origin
		.. string.char(self.width  % 256, math.floor(self.width  / 256)) -- width
		.. string.char(self.height % 256, math.floor(self.height / 256)) -- height
		.. string.char(24) -- pixel depth (RGB = 3 bytes = 24 bits)
		.. string.char(0) -- image descriptor
end

function image:encode_header()
	self.data = self.data
		.. string.char(0) -- image id
		.. string.char(0) -- color map type
		.. string.char(2) -- image type (uncompressed true-color image = 2)
	self:encode_colormap_spec() -- color map specification
	self:encode_image_spec() -- image specification
end

function image:encode_data()
	for _, row in ipairs(self.pixels) do
		for _, pixel in ipairs(row) do
			self.data = self.data
				.. string.char(pixel[3], pixel[2], pixel[1])
		end
	end
end

function image:encode_footer()
	self.data = self.data
		.. string.char(0, 0, 0, 0) -- extension area offset
		.. string.char(0, 0, 0, 0) -- developer area offset
		.. "TRUEVISION-XFILE"
		.. "."
		.. string.char(0)
end

function image:encode()
	self:encode_header() -- header
	-- no color map and image id data
	self:encode_data() -- encode data
	-- no extension or developer area
	self:encode_footer() -- footer
end

function image:save(filename)
	local f = assert(io.open(filename, "w"))
	f:write(self.data)
	f:close()
end

tga_encoder.image = image
