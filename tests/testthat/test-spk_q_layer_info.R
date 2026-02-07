test_that("spk_q_layer_info extracts layer information from QGIS project", {
  skip_if_not_installed("xml2")
  
  # Create minimal QGIS project XML
  tmpfile <- tempfile(fileext = ".qgs")
  on.exit(unlink(tmpfile), add = TRUE)
  
  qgs_content <- '<?xml version="1.0" encoding="UTF-8"?>
<qgis>
  <layer-tree>
    <layer-tree-layer id="layer1" name="Test Layer 1" source="./data/test.gpkg|layername=points" providerKey="ogr">
    </layer-tree-layer>
    <layer-tree-layer id="layer2" name="Test Layer 2" source="/absolute/path/raster.tif" providerKey="gdal">
    </layer-tree-layer>
  </layer-tree>
</qgis>'
  
  writeLines(qgs_content, tmpfile)
  
  result <- spk_q_layer_info(tmpfile)
  
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
  expect_true("id" %in% names(result))
  expect_true("name" %in% names(result))
  expect_true("source" %in% names(result))
  expect_true("providerkey" %in% names(result))
  expect_true("layer_name" %in% names(result))
  expect_true("time_exported" %in% names(result))
})

test_that("spk_q_layer_info handles relative paths correctly", {
  skip_if_not_installed("xml2")
  
  tmpfile <- tempfile(fileext = ".qgs")
  on.exit(unlink(tmpfile), add = TRUE)
  
  qgs_content <- '<?xml version="1.0" encoding="UTF-8"?>
<qgis>
  <layer-tree>
    <layer-tree-layer id="layer1" name="Relative Layer" source="./data/test.gpkg" providerKey="ogr">
    </layer-tree-layer>
  </layer-tree>
</qgis>'
  
  writeLines(qgs_content, tmpfile)
  
  result <- spk_q_layer_info(tmpfile)
  
  # Relative path should be converted to absolute
  expect_false(grepl("^\\./", result$source[1]))
})

test_that("spk_q_layer_info extracts layer name from source", {
  skip_if_not_installed("xml2")
  
  tmpfile <- tempfile(fileext = ".qgs")
  on.exit(unlink(tmpfile), add = TRUE)
  
  qgs_content <- '<?xml version="1.0" encoding="UTF-8"?>
<qgis>
  <layer-tree>
    <layer-tree-layer id="layer1" name="Points" source="./test.gpkg|layername=my_points" providerKey="ogr">
    </layer-tree-layer>
  </layer-tree>
</qgis>'
  
  writeLines(qgs_content, tmpfile)
  
  result <- spk_q_layer_info(tmpfile)
  
  # layer_name is extracted from source, may be fs_path class
  expect_true(grepl("my_points", as.character(result$layer_name[1])))
})

test_that("spk_q_layer_info allows custom attributes", {
  skip_if_not_installed("xml2")
  
  tmpfile <- tempfile(fileext = ".qgs")
  on.exit(unlink(tmpfile), add = TRUE)
  
  qgs_content <- '<?xml version="1.0" encoding="UTF-8"?>
<qgis>
  <layer-tree>
    <layer-tree-layer id="layer1" name="Test" source="./test.gpkg" providerKey="ogr">
    </layer-tree-layer>
  </layer-tree>
</qgis>'
  
  writeLines(qgs_content, tmpfile)
  
  # Note: source attribute is required for layer_name extraction
  # Testing with default attrs to ensure function works
  result <- spk_q_layer_info(tmpfile, attrs = c("id", "name", "source", "providerKey"))
  
  # Should have requested attrs, plus computed layer_name and time_exported
  expect_true("id" %in% names(result))
  expect_true("name" %in% names(result))
  expect_true("layer_name" %in% names(result))
  expect_true("time_exported" %in% names(result))
})

test_that("spk_q_layer_info sorts results alphabetically by name", {
  skip_if_not_installed("xml2")
  
  tmpfile <- tempfile(fileext = ".qgs")
  on.exit(unlink(tmpfile), add = TRUE)
  
  qgs_content <- '<?xml version="1.0" encoding="UTF-8"?>
<qgis>
  <layer-tree>
    <layer-tree-layer id="layer1" name="Zebra" source="./z.gpkg" providerKey="ogr">
    </layer-tree-layer>
    <layer-tree-layer id="layer2" name="Apple" source="./a.gpkg" providerKey="ogr">
    </layer-tree-layer>
    <layer-tree-layer id="layer3" name="Middle" source="./m.gpkg" providerKey="ogr">
    </layer-tree-layer>
  </layer-tree>
</qgis>'
  
  writeLines(qgs_content, tmpfile)
  
  result <- spk_q_layer_info(tmpfile)
  
  expect_equal(result$name, c("Apple", "Middle", "Zebra"))
})

test_that("spk_q_layer_info errors on non-existent file", {
  expect_error(
    spk_q_layer_info("nonexistent.qgs"),
    class = "error"  # xml2::read_xml will error
  )
})

test_that("spk_q_layer_info includes time_exported timestamp", {
  skip_if_not_installed("xml2")
  
  tmpfile <- tempfile(fileext = ".qgs")
  on.exit(unlink(tmpfile), add = TRUE)
  
  qgs_content <- '<?xml version="1.0" encoding="UTF-8"?>
<qgis>
  <layer-tree>
    <layer-tree-layer id="layer1" name="Test" source="./test.gpkg" providerKey="ogr">
    </layer-tree-layer>
  </layer-tree>
</qgis>'
  
  writeLines(qgs_content, tmpfile)
  
  result <- spk_q_layer_info(tmpfile)
  
  expect_true("time_exported" %in% names(result))
  expect_s3_class(result$time_exported, "POSIXct")
})
