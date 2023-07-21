from setuptools import setup, find_packages

setup(
    name='swiftly-windows',
    version='0.0.16',
    packages=find_packages(),
    scripts=['scripts/swiftly.bat'],
)