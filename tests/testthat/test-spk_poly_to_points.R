# Create a simple polygon dataset with known densities
poly <- sf::st_sf(
  region = c("A", "B"),
  col_density = c(0.75, 5),  # 1 point/m² and 5 points/m²
  geometry = sf::st_sfc(
    sf::st_polygon(list(rbind(c(0, 0), c(100, 0), c(100, 10), c(0, 100), c(0, 0)))),
    sf::st_polygon(list(rbind(c(150, 150), c(200, 150), c(200, 200), c(150, 200), c(150, 150))))
  )
)

# Run function
points <- spk_poly_to_points(poly, col_density = "col_density", col_id = "region")


test_that("spk_poly_to_points generates correct number of points within tolerance", {

  # Expected number of points (density * area)
  expected_A <- as.integer(poly$col_density[1] * sf::st_area(poly[1, ]))
  expected_B <- as.integer(poly$col_density[2] * sf::st_area(poly[2, ]))

  # Tolerance range (±5%)
  tol <- 0.05
  lower_A <- expected_A * (1 - tol)
  upper_A <- expected_A * (1 + tol)
  lower_B <- expected_B * (1 - tol)
  upper_B <- expected_B * (1 + tol)

  # Check total point count within tolerance
  actual_A <- sum(points$region == "A")
  actual_B <- sum(points$region == "B")

  expect_true(lower_A <= actual_A && actual_A <= upper_A,
              info = paste("Expected:", expected_A, "Actual:", actual_A))
  expect_true(lower_B <= actual_B && actual_B <= upper_B,
              info = paste("Expected:", expected_B, "Actual:", actual_B))
})

test_that("spk_poly_to_points retains correct ID column name", {

  # Ensure the column name is "region"
  expect_true("region" %in% names(points), info = paste("Expected column 'region', found:", names(points)))
})

test_that("spk_poly_to_points assigns 'id' as default column name when col_id is NULL", {
  poly_no_id <- sf::st_sf(
    col_density = c(2, 4),  # Different densities per polygon
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(c(0, 0), c(5, 0), c(5, 5), c(0, 5), c(0, 0)))),
      sf::st_polygon(list(rbind(c(10, 10), c(15, 10), c(15, 15), c(10, 15), c(10, 10))))
    )
  )
  points <- spk_poly_to_points(poly_no_id, col_density = "col_density")

  # Ensure the column name is "id"
  expect_true("id" %in% names(points), info = paste("Expected column 'id', found:", names(points)))
})

test_that("spk_poly_to_points retains the original CRS", {
  # Create a simple polygon with a known CRS (UTM Zone 9)
  poly <- sf::st_sf(
    region = c("A"),
    col_density = c(2),
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(c(0, 0), c(10, 0), c(10, 10), c(0, 10), c(0, 0))))
    ),
    crs = 32609  # UTM Zone 9N
  )

  # Run function
  points <- spk_poly_to_points(poly, col_density = "col_density", col_id = "region")

  # Check that the CRS of the result matches the input
  expect_equal(sf::st_crs(points), sf::st_crs(poly))
})


