library(tidyverse)
library(rvest)
library(RSelenium)
library(data.table)

# Create driver object
rs_driver_object <- rsDriver(browser = "chrome",
                             chromever = "117.0.5938.92",
                             verbose = F,
                             port = 4444L)

# Connect to client
remDr <- rs_driver_object$client

# Open sitemap index page
remDr$navigate("https://sailboatdata.com/sitemap_index.xml")

data_table <- remDr$findElement(using = "id", "sitemap") # Locate dynamic index table

# Read table html
data_table_html <- data_table$getPageSource()
page <- read_html(data_table_html %>% unlist())
df <- data.frame(html_table(page)) %>%
  select(Sitemap) %>%
  filter(grepl("https://sailboatdata.com/sailboat-sitemap", Sitemap)) # Only select urls with sailboat data

boat_urls <- data.frame() # Create empty data frame
i <- 1 # Set counter to 1

# Loop to extract url for each sailboat links page (1000 urls per page)
while (i <= nrow(df))
{
  remDr$navigate(df[i,1])
  data_table <- remDr$findElement(using = "id", "sitemap")
  data_table_html <- data_table$getPageSource()
  page <- read_html(data_table_html %>% unlist())
  urls_to_add <- data.frame(html_table(page)) %>%
    select(URL) # Only select url column
  boat_urls <- rbind(boat_urls, urls_to_add)
  i <- i + 1
}

boat_models <- data.frame() # Create empty data frame
i <- 1 # Set counter to 1

# Loop to extract model and table elements for each sailboat
while (i <= nrow(boat_urls))
{
  webpage <- read_html(boat_urls[i,1])
  name_node <- html_nodes(webpage, "h1") %>%
    html_text() # Extract model name
  table_node <- html_nodes(webpage, "table")[[1]]
  model_to_add <- data.frame(html_table(table_node)) %>% # Extract dynamic table elements
    mutate(X1 = str_sub(X1, start = 1, end = -2)) %>% # Remove colon at the end of each header
    pivot_wider(names_from = X1, values_from = X2) %>%
    mutate(Model = str_to_title(name_node)) %>% # Add model and change from all caps to match other headers
    relocate(Model) # Move model column to first position
  boat_models <- bind_rows(boat_models, model_to_add)
  i <- i + 1
}

# Save data frame to .csv file
write_csv(boat_models, "Sailboat Data.csv")
