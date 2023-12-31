# Load necessry libraries
if(!require(keras)) {
  install.packages("keras")
}
library(tidyverse)
library(keras)
library(data.table)
library(terra)
library(tensorflow)
library(reticulate)
library(RColorBrewer)
library(Giotto)
library(e1071)
library(caTools)

#select the conda environment 
reticulate::use_condaenv("/projectnb/rd-spat/HOME/ivycwf/.conda/envs/giotto_env_keras/bin/python")

#Load visium data
load(file ="/projectnb/rd-spat/HOME/ivycwf/project_1/sample_119B/visium_119B.RData")


# Generates deep copy of SpatRaster
# full_image <- Giotto::createGiottoLargeImage("/projectnb/rd-spat/HOME/ivycwf/project_1/resolution/119B.tif")
# 
# 
# #put an large image in the Giotto object
# visium_sample_119B@largeImages <- list(image = full_image)
# 
# 
# #Get the full size image spatialRaster
# fullsize_sr <- full_image@raster_object
#spatPlot2D(visium_sample_119B, show_image = T, largeImage_name = "image")


#Get all the coordinates of spots from "cell coords"
cell_coords <- readRDS(file = "/projectnb/rd-spat/HOME/ivycwf/project_1/resolution/patch_tiles_4tiles/s119B_cell_coords.RDS")


# Train the resnet model in patch_run_resnet_model.R
load(file = "/projectnb/rd-spat/HOME/ivycwf/project_1/resolution/patch_tiles_4tiles/s119B_patch_resnet50_extracted_feats.RData")
#Have "res_dfr", "image_mat" variable in it (resnet50 features)

#load(file = "/projectnb/rd-spat/HOME/ivycwf/project_1/resolution/patch_tiles_4tiles/s119B_patch_vgg16_extracted_feats.RData")
#Have "res_dfr", "tile_names", "image_mat" variable in it (vgg16 features)
#res_dfr -- contain all the features from each spot-covered tiles before performing PCA


#Get the patch number with corresponding extent # with "cells_order" variable in it
load(file = "/projectnb/rd-spat/HOME/ivycwf/project_1/resolution/patch_tiles_4tiles/s119B_patch_after_maketiles.RData")


# Check features matrix from resnet50 model
any(is.nan(image_mat))


# cells_order Get From make_patch_tiles_4tiles.R file
patches_info <- dplyr::inner_join(cell_coords, cells_order, by = c("xmin", "xmax", "ymin", "ymax"))

#Get the information of expression that links to the tiles
##Get the all the tile names
list_files = res_dfr[,1]

#Concat cell ID,  path number, and tilename in a tibble
#patch_info <- data.frame(cell_ID = cell_coords$cell_ID, patch_num = c(1:501))
tile_name <- data.frame( tile_name = sapply(list_files,basename), patch_number = as.numeric(gsub("s119B_(\\d+)_\\d+\\.tif", "\\1", sapply(list_files,basename))))
patch_tile_info <- data.frame()
patch_tile_info <- dplyr::right_join(patches_info, tile_name, by = c("patch_number" = "patch_number"), multiple = "all")

#Get normalized visium gene expression of all genes
scaled_expr_mt <-Giotto::getExpression(visium_sample_119B, values = "scaled",spat_unit = "cell", feat_type = "rna", output = "matrix")%>% 
  as.matrix()

#Get the expression values of specific spatial genes (Breast cancer related marker genes)
spatial_genes <-data.frame()
spatial_genes <- t(scaled_expr_mt[c("SPARC","COL1A1","LUM","SFRP2","COL3A1","SULF1","COL1A2","VCAN","IGFBP7","COL18A1","THY1"), , drop = FALSE]) %>% 
  as.data.frame()
spatial_genes <-  mutate(spatial_genes, cell_ID = rownames(spatial_genes))
patch_tile_info <- dplyr::inner_join(patch_tile_info, spatial_genes, by = c("cell_ID" = "cell_ID"))

#Concat spatial gene's expression that is associating with those tiles to the df
tiles_df <- data.frame(
  tile_ID = unlist(list_files),
  tile_name = sapply(list_files,basename),
  x_cor = sapply(list_files, function(file) ext(rast(file))[1] + 50),
  y_cor = sapply(list_files, function(file) ext(rast(file))[3] + 50)
)
rownames(tiles_df)<- NULL


#Combine all the tile-related info together
tile_plot_df <- data.frame()
tile_plot_df <- dplyr::inner_join(patch_tile_info, tiles_df, by = c("tile_name" = "tile_name"))


# Use original features from Resnet50 / vgg16 model would be reliable than using PCs
#image_mat already load from "patch_tiles_4tiles/s119B_patch_resnet50_extracted_feats.RData"
#                         or "patch_tiles_4tiles/s119B_patch_vgg16_extracted_feats.RData"


# modify the column names avoid using number as column names
image_mat <- image_mat%>% as.data.frame()
colnames(image_mat) <- paste0("f", seq_along(image_mat))


#Combine the features with the corresponding tile name 
features_matrix <-cbind(sapply(res_dfr[,1], basename), image_mat) 
colnames(features_matrix)[1] <- "tile_name"
rownames(features_matrix) <- NULL



#Create input matrix #Do not need to do this every time.
input_mat <- data.frame()
input_mat <- dplyr::inner_join(features_matrix, tile_plot_df[,9:20], by = c("tile_name" = "tile_name")) #select target gene and tile_ID columns
#input_mat include tile_name, original 2048 features, and target genes' expression (resnet50)
                            #original 512 features (VGG16)

#Don't need to do this every time (unless you made some changes in input_mat)
#saveRDS(input_mat, file = "/projectnb/rd-spat/HOME/ivycwf/project_1/resolution/patch_tiles_4tiles/input_mat.RDS") 
#saveRDS(tile_plot_df, file = "/projectnb/rd-spat/HOME/ivycwf/project_1/resolution/patch_tiles_4tiles/tile_plot_df.RDS") 

#saveRDS(input_mat, file = "/projectnb/rd-spat/HOME/ivycwf/project_1/resolution/patch_tiles_4tiles/input_mat_vgg.RDS") 
#saveRDS(tile_plot_df, file = "/projectnb/rd-spat/HOME/ivycwf/project_1/resolution/patch_tiles_4tiles/tile_plot_df_vgg.RDS") 

