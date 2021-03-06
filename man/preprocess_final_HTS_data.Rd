% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/preprocess_final_HTS_data.R
\name{preprocess_final_HTS_data}
\alias{preprocess_final_HTS_data}
\title{Pre-process final HTS data for downstream analysis}
\usage{
preprocess_final_HTS_data(methyl_region, prom_reg, rna_data,
  gene_log2_transf = TRUE, gene_outl_thresh = TRUE, gex_outlier = 300)
}
\arguments{
\item{methyl_region}{Methylation region data, which are the output of the
"\code{create_methyl_region}" function.}

\item{prom_reg}{A \code{\link[GenomicRanges]{GRanges}} object containing
corresponding annotated promoter regions for each entry of the
\code{methyl_region} list.}

\item{rna_data}{A \code{\link[GenomicRanges]{GRanges}} object containing
corresponding RNA-Seq data for each entry of the \code{methyl_region} list.
This is the output of the "\code{read_rna_encode_caltech} function.}

\item{gene_log2_transf}{Logical, whether or not to log2 transform the gene
expression data.}

\item{gene_outl_thresh}{Logical, whehter or not to remove outlier gene
expression data.}

\item{gex_outlier}{Numeric, denoting the threshold above of which the gene
expression data (before the log2 transformation) are considered as noise.}
}
\value{
An object which contains following information: \itemize{ \item
  \code{methyl_region}: The subset of promoter methylation region data after
  the filtering process. \item \code{gex}: A vectoring storing only the
  corresponding gene expression values for each promoter region. \item
  \code{rna_data}: The corresponding gene expression data stored as a GRanges
  object.}
}
\description{
\code{preprocess_final_HTS_data} performs a final filtering and preprocessing
on the data for use in downstream analysis. These include, removing noisy
gene expression data, removing or not un-expressed genes and log2-transorming
of the FPKM values.
}
\examples{
# Obtain the path to the BS file and then read it
bs_file <- system.file("extdata", "rrbs.bed", package = "BPRMeth")
bs_data <- read_bs_encode_haib(bs_file)

# Create promoter regions
rnaseq_file <- system.file("extdata", "rnaseq.bed", package = "BPRMeth")
annot_data <- read_rna_encode_caltech(rnaseq_file)
prom_region <- create_prom_region(annot_data)

# Create methylation regions
methyl_region <- create_methyl_region(bs_data, prom_region)

# Finally preprocess the HTS data
res <- preprocess_final_HTS_data(methyl_region, prom_region, annot_data)

}
\author{
C.A.Kapourani \email{C.A.Kapourani@ed.ac.uk}
}
\seealso{
\code{\link{read_rna_encode_caltech}}
  \code{\link{process_haib_caltech_wrap}}
}

