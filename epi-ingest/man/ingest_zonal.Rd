\name{ingest_zonal}
\alias{ingest_zonal}
\title{从栅格提取面单元协变量}
\description{
把气温、NDVI、PM2.5 等栅格按月提取到地区，作为下游模型的协变量。
需要 \pkg{terra}；缺包时明确报错并给出安装提示，不返回空表。
}
\usage{
ingest_zonal(path, polygons, region_col = "region",
             stats = c("mean"), names_prefix = "cov", layer = NULL)
}
\arguments{
  \item{path}{栅格文件路径（GeoTIFF / NetCDF 等）或 \code{SpatRaster}。}
  \item{polygons}{面数据：\code{sf} / \code{SpatVector}，或可被 \pkg{terra} 转换的对象。}
  \item{region_col}{面数据中的地区编码列名。}
  \item{stats}{统计量，可多选 \code{mean} / \code{sum} / \code{min} / \code{max} / \code{sd}。}
  \item{names_prefix}{输出列名前缀。}
  \item{layer}{栅格图层名或序号。}
}
\value{data.frame，首列为 region，其余为「前缀_统计量_图层名」的协变量列。}
\examples{
\dontrun{
cov <- ingest_zonal("temp_2021.tif", polygons = geo_sf,
                    stats = c("mean", "max"), names_prefix = "temp")
}
}
