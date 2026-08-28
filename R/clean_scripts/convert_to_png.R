library(pdftools)
library(rmarkdown)

pdf_convert("R/clean_scripts/get_data_obs.pdf", format = "jpg", dpi = 300,
            filenames = "paper_figures/figure_s3.jpg")
pdf_convert("R/clean_scripts/load.pdf", format = "jpg", dpi = 300,
            filenames = "paper_figures/figure_s4.jpg")
pdf_convert("R/clean_scripts/space_downscale.pdf", format = "jpg", dpi = 300,
            filenames = "paper_figures/figure_s5.jpg")
pdf_convert("R/clean_scripts/skill_plot.pdf", format = "jpg", dpi = 300,
            filenames = "paper_figures/figure_s7.jpg")