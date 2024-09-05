#!/usr/bin/env bash

# Bulunduğunuz klasörün adını alın
current_dir=$(basename "$PWD")

# Klasör adını küçük harflere çevirin ve "_fixed.pdb" ekleyin
pdb_file="${current_dir,,}_fixed.pdb"

echo "PDB file automatically set to: $pdb_file"

# Dosya adı kontrolü
if [ ! -f "$pdb_file" ]; then
    echo "File not found! Please check if the file exists."
    exit 1
fi

pdb_name=${pdb_file%.*}
gro="${pdb_name}_clean.gro"



# delete the clean fro file so gromacs wont display silly backup messages
if [ -e $gro ]
then
  rm -f $gro
fi


# --> select force-field 1
gmx_mpi pdb2gmx -f $pdb_file -o $gro -water spce -ignh

# --> set the box
gmx_mpi editconf -f $gro -o "${gro%.*}_box.gro" -c -d 1.0 -bt cubic


# --> solvate
gmx_mpi solvate -cp "${gro%.*}_box.gro" -cs spc216.gro -o "${gro%.*}_solv.gro" -p topol.top


# --> ionize
gmx_mpi grompp -f mdp_files/ions.mdp -c "${gro%.*}_solv.gro" -p topol.top -o ions.tpr -maxwarn 3


# --> select 13 for ions to replace SOL
gmx_mpi genion -s ions.tpr -o "${gro%.*}_ionized.gro" -p topol.top -pname NA -nname CL -neutral


# --> energy minimization
gmx_mpi grompp -f mdp_files/minim.mdp -c "${gro%.*}_ionized.gro" -p topol.top -o em.tpr
gmx_mpi mdrun -v -deffnm em


# --> stabilize the temperature 
gmx_mpi grompp -f mdp_files/nvt.mdp -c em.gro -p topol.top -o nvt.tpr -r em.gro
gmx_mpi mdrun -v -deffnm nvt


# --> stabilize the pressure
gmx_mpi grompp -f mdp_files/npt.mdp -c nvt.gro -t nvt.cpt -p topol.top -o npt.tpr -r nvt.gro
gmx_mpi mdrun -v -deffnm npt


# --> mdrun
gmx_mpi grompp -f mdp_files/md.mdp -c npt.gro -t npt.cpt -p topol.top -o "${gro%.*}_run".tpr
gmx_mpi mdrun -v -gpu_id 0 -deffnm "${gro%.*}_run"
