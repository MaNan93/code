from setuptools import setup, find_packages

setup(
    name='cellgen',
    version='1.1.0',
    packages=find_packages(where='src'),
    package_dir={'': 'src'},
    python_requires='>=3.6.8',
    entry_points={
        'console_scripts': [
            'cellgen=cellgen.main:main',
        ],
    },
    install_requires=[],
)
