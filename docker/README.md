# To build Docker image

```bash
IMAGE=pstothard/cgview_comparison_tool
VERSION=1.0.0
rsync -r --exclude=".*" ../bin .
rsync -r --exclude=".*" ../conf .
rsync -r --exclude=".*" --exclude="test_output" ../lib .
rsync -r -l --exclude=".*" ../scripts .
rsync -r --exclude=".*" ../test_projects .
tar xvfz ./bin/legacy_blast/blast-2.2.26-x64-linux.tar.gz -C ./bin/legacy_blast/
docker build -t ${IMAGE}:${VERSION} .
docker tag ${IMAGE}:${VERSION} ${IMAGE}:latest
```
