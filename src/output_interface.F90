module output_interface

  use constants
  use error,         only: warning
  use global
  use tally_header,  only: TallyResult

#ifdef HDF5
  use hdf5_interface
#elif MPI
  use mpiio_interface
#endif

  implicit none

  ! Generic write procedure interface 
  interface write_data
    module procedure write_double
    module procedure write_double_1Darray
    module procedure write_double_2Darray
    module procedure write_double_3Darray
    module procedure write_integer
    module procedure write_integer_1Darray
    module procedure write_integer_2Darray
    module procedure write_integer_3Darray
    module procedure write_long
    module procedure write_string
  end interface write_data

  ! Generic read procedure interface
  interface read_data
    module procedure read_double
    module procedure read_double_1Darray
    module procedure read_integer
    module procedure read_integer_1Darray
    module procedure read_long
    module procedure read_string
  end interface read_data

contains

!===============================================================================
! FILE_CREATE creates a new file to write data to
!===============================================================================

  subroutine file_create(filename, fh_str, proc_id)

    character(*),      intent(in) :: filename    ! name of file to be created
    character(*),      intent(in) :: fh_str      ! parallel or serial HDF5 file
    integer, optional, intent(in) :: proc_id     ! processor rank to write from

    integer :: proc_create = 0 ! processor writing in serial (default master)

#ifdef HDF5
# ifdef MPI
    ! Check for proc id
    if (present(proc_id)) proc_create = proc_id

    ! Determine whether the file should be created by 1 or all procs
    if (trim(fh_str) == 'serial') then
      if(rank == proc_create) call hdf5_file_create(filename, hdf5_fh)
    else
      call hdf5_parallel_file_create(filename, hdf5_fh)
    endif
# else
    call hdf5_file_create(filename, hdf5_fh)
# endif
#elif MPI
    call mpi_create_file(filename, mpi_fh)
#else
    open(UNIT=UNIT_OUTPUT, FILE=filename, ACTION="write", &
         STATUS='replace', ACCESS='stream')
#endif

  end subroutine file_create

!===============================================================================
! FILE_OPEN opens an existing file for reading or read/writing
!===============================================================================

  subroutine file_open(filename, fh_str, mode, proc_id)

    character(*),      intent(in) :: filename ! name of file to be opened
    character(*),      intent(in) :: fh_str   ! parallel or serial HDF5 file
    character(*),      intent(in) :: mode     ! file access mode 
    integer, optional, intent(in) :: proc_id  ! processor rank to open file

    integer :: proc_open = 0 ! processor to open file (default is master)

#ifdef HDF5
# ifdef MPI
    ! Check for proc_id
    if (present(proc_id)) proc_open = proc_id

    ! Determine if the file should be opened by 1 or all procs
    if (trim(fh_str) == 'serial') then
      if (rank == proc_open) call hdf5_file_open(filename, hdf5_fh, mode)
    else
      call hdf5_parallel_file_open(filename, hdf5_fh, mode)
    endif
# else
    call hdf5_file_open(filename, hdf5_fh, mode)
# endif
#elif MPI
    call mpi_open_file(filename, mpi_fh, mode)
#else
    ! Check for read/write mode to open, default is read only
    if (mode == 'w') then
      open(UNIT=UNIT_OUTPUT, FILE=filename, ACTION='write', &
           STATUS='old', ACCESS='stream')
    else
      open(UNIT=UNIT_OUTPUT, FILE=filename, ACTION='read', &
           STATUS='old', ACCESS='stream')
    end if
#endif

  end subroutine file_open

!===============================================================================
! FILE_CLOSE closes a file
!===============================================================================

  subroutine file_close(fh_str, proc_id)

    character(*),      intent(in) :: fh_str  ! serial or parallel hdf5 file
    integer, optional, intent(in) :: proc_id ! processor rank to close file

    integer :: proc_close = 0 ! processor to close file

#ifdef HDF5
# ifdef MPI
    ! Check for proc_id
    if (present(proc_id)) proc_close = proc_id

    ! Determine whether a file should be closed by 1 or all procs
    if (trim(fh_str) == 'serial') then
     if(rank == proc_close) call hdf5_file_close(hdf5_fh)
   else
     call hdf5_file_close(hdf5_fh)
    endif
# else
     call hdf5_file_close(hdf5_fh)
# endif
#elif MPI
     call mpi_close_file(mpi_fh)
#else
     close(UNIT=UNIT_OUTPUT)
#endif

  end subroutine file_close

!===============================================================================
! WRITE_DOUBLE writes double precision scalar data
!===============================================================================

  subroutine write_double(buffer, name, group)

    real(8),      intent(in)           :: buffer ! data to write
    character(*), intent(in)           :: name   ! name for data
    character(*), intent(in), optional :: group  ! HDF5 group name

#ifdef HDF5
    ! Check if HDF5 group should be created/opened
    if (present(group)) then
      call hdf5_open_group(group)
    else
      temp_group = hdf5_fh
    endif

    ! Write the data
    call hdf5_write_double(temp_group, name, buffer)

    ! Check if HDF5 group should be closed
    if (present(group)) call hdf5_close_group()
#elif MPI
    call mpi_write_double(mpi_fh, buffer)
#else
    write(UNIT_OUTPUT) buffer
#endif

  end subroutine write_double

!===============================================================================
! READ_DOUBLE reads double precision scalar data
!===============================================================================

  subroutine read_double(buffer, name, group, option)

    real(8),      intent(inout)        :: buffer ! read data to here 
    character(*), intent(in)           :: name   ! name for data
    character(*), intent(in), optional :: group  ! HDF5 group name
    character(*), intent(in), optional :: option ! type of read

#ifdef HDF5
    ! Check if HDF5 group should be created/opened
    if (present(group)) then
      call hdf5_open_group(group)
    else
      temp_group = hdf5_fh
    endif
# ifdef MPI
    ! Check for option for reading default is independent
    if (present(option)) then
      if (option == 'collective') then
        call hdf5_parallel_read_double(temp_group, name, buffer, &
             H5FD_MPIO_COLLECTIVE_F)
      else
        call hdf5_parallel_read_double(temp_group, name, buffer, &
             H5FD_MPIO_INDEPENDENT_F)
      end if
    else
      ! Standard read call
      call hdf5_read_double(temp_group, name, buffer)
    end if
# else
    ! Read the data serial
    call hdf5_read_double(temp_group, name, buffer)
# endif
    ! Check if HDf5 group should be closed
    if (present(group)) call hdf5_close_group()
#elif MPI
    call mpi_read_double(mpi_fh, buffer)
#else
    read(UNIT_OUTPUT) buffer
#endif

  end subroutine read_double

!===============================================================================
! WRITE_DOUBLE_1DARRAY writes double presicions 1-D array data
!===============================================================================

  subroutine write_double_1Darray(buffer, name, group, length)

    integer,      intent(in)           :: length    ! length of array to write
    real(8),      intent(in)           :: buffer(:) ! data to write
    character(*), intent(in)           :: name      ! name of data
    character(*), intent(in), optional :: group     ! HDF5 group name

#ifdef HDF5
    ! Check if HDF5 group should be created/opened
    if (present(group)) then
      call hdf5_open_group(group)
    else
      temp_group = hdf5_fh
    endif

    ! Write the data
    call hdf5_write_double_1Darray(temp_group, name, buffer, length)

    ! Check if HDF5 group should be closed
    if (present(group)) call hdf5_close_group()
#elif MPI
    call mpi_write_double_1Darray(mpi_fh, buffer, length)
#else
    write(UNIT_OUTPUT) buffer(1:length)
#endif

  end subroutine write_double_1Darray

!===============================================================================
! READ_DOUBLE_1DARRAY reads double precision 1-D array data
!===============================================================================

  subroutine read_double_1Darray(buffer, name, group, length, option)

    integer,        intent(in)           :: length    ! length of array to read
    real(8),        intent(inout)        :: buffer(:) ! read data to here
    character(*),   intent(in)           :: name      ! name of data
    character(*),   intent(in), optional :: group     ! HDF5 group name
    character(*),   intent(in), optional :: option    ! read option

#ifdef HDF5
    ! Check if HDF5 group should be created/opened
    if (present(group)) then
      call hdf5_open_group(group)
    else
      temp_group = hdf5_fh
    endif
# ifdef MPI
    ! Check for option for reading default is independent
    if (present(option)) then
      if (option == 'collective') then
        call hdf5_parallel_read_double_1Darray(temp_group, name, buffer, &
             length, H5FD_MPIO_COLLECTIVE_F)
      else 
        call hdf5_parallel_read_double_1Darray(temp_group, name, buffer, &
             length, H5FD_MPIO_INDEPENDENT_F)
      end if
    else
      ! Standard read call
      call hdf5_read_double_1Darray(temp_group, name, buffer, length)
    end if
# else
    ! Read the data serial
    call hdf5_read_double_1Darray(temp_group, name, buffer, length)
# endif
    ! Check if HDF5 group should be closed
    if (present(group)) call hdf5_close_group()
#elif MPI
    call mpi_read_double_1Darray(mpi_fh, buffer, length)
#else
    read(UNIT_OUTPUT) buffer(1:length)
#endif

  end subroutine read_double_1Darray

!===============================================================================
! WRITE_DOUBLE_2DARRAY writes double precision 2-D array data
!===============================================================================

  subroutine write_double_2Darray(buffer, name, group, length)

    integer,      intent(in)           :: length(2) ! dimension of array
    real(8),      intent(in)           :: buffer(length(1),length(2)) ! the data
    character(*), intent(in)           :: name ! name of data
    character(*), intent(in), optional :: group ! HDF5 group name

#ifdef HDF5
    ! Check if HDF5 group should be created/opened
    if (present(group)) then
      call hdf5_open_group(group)
    else
      temp_group = hdf5_fh
    endif

    ! Write the data
    call hdf5_write_double_2Darray(temp_group, name, buffer, length)

    ! Check if HDF5 group should be closed
    if (present(group)) call hdf5_close_group()
#else
    message = 'Double precision 2-D array writing not currently supported'
    call warning()
#endif

  end subroutine write_double_2Darray

!===============================================================================
! WRITE_DOUBLE_3DARRAY writes double precision 3-D array data
!===============================================================================

  subroutine write_double_3Darray(buffer, name, group, length)

    integer,      intent(in)           :: length(3) ! length of each dimension
    real(8),      intent(in)           :: buffer(length(1),length(2),length(3))        
    character(*), intent(in)           :: name ! name of data
    character(*), intent(in), optional :: group ! HDF5 group name

#ifdef HDF5
    ! Check if HDF5 group should be created/opened
    if (present(group)) then
      call hdf5_open_group(group)
    else
      temp_group = hdf5_fh
    endif

    ! Write the data
    call hdf5_write_double_3Darray(temp_group, name, buffer, length)

    ! Check if HDF5 group should be closed
    if (present(group)) call hdf5_close_group()
#else
    message = 'Double precision 3-D array writing not currently supported'
    call warning()
#endif

  end subroutine write_double_3Darray

!===============================================================================
! WRITE_INTEGER writes integer scalar data
!===============================================================================

  subroutine write_integer(buffer, name, group)

    integer,      intent(in)           :: buffer ! data to write
    character(*), intent(in)           :: name   ! name of data
    character(*), intent(in), optional :: group  ! HDF5 group name

#ifdef HDF5
    ! Check if HDF5 group should be created/opened
    if (present(group)) then
      call hdf5_open_group(group)
    else
      temp_group = hdf5_fh
    endif

    ! Write data
    call hdf5_write_integer(temp_group, name, buffer)

    ! Check if HDF5 group should be closed
    if (present(group)) call hdf5_close_group()
#elif MPI
    call mpi_write_integer(mpi_fh, buffer)
#else
    write(UNIT_OUTPUT) buffer
#endif

  end subroutine write_integer

!===============================================================================
! READ_INTEGER reads integer scalar data
!===============================================================================

  subroutine read_integer(buffer, name, group, option)

    integer,      intent(inout)        :: buffer ! read data to here
    character(*), intent(in)           :: name   ! name of data
    character(*), intent(in), optional :: group  ! HDF5 group name
    character(*), intent(in), optional :: option ! read option

#ifdef HDF5
    ! Check if HDF5 group should be created/opened
    if (present(group)) then
      call hdf5_open_group(group)
    else
      temp_group = hdf5_fh
    endif
# ifdef MPI
    ! Check for option for reading default is independent
    if (present(option)) then
      if (option == 'collective') then
        call hdf5_parallel_read_integer(temp_group, name, buffer, &
             H5FD_MPIO_COLLECTIVE_F)
      else 
        call hdf5_parallel_read_integer(temp_group, name, buffer, &
             H5FD_MPIO_INDEPENDENT_F)
      end if
    else
      ! Standard read call
      call hdf5_read_integer(temp_group, name, buffer)
    end if
# else
    ! Read the data serial
    call hdf5_read_integer(temp_group, name, buffer)
# endif
    ! Check if HDF5 group should be closed
    if (present(group)) call hdf5_close_group()
#elif MPI
    call mpi_read_integer(mpi_fh, buffer)
#else
    read(UNIT_OUTPUT) buffer
#endif

  end subroutine read_integer

!===============================================================================
! WRITE_INTEGER_1DARRAY writes integer 1-D array data
!===============================================================================

  subroutine write_integer_1Darray(buffer, name, group, length)

    integer,      intent(in)           :: length    ! length of array to write
    integer,      intent(in)           :: buffer(:) ! data to write
    character(*), intent(in)           :: name      ! name of data
    character(*), intent(in), optional :: group     ! HDF5 group name

#ifdef HDF5

    ! Check if HDF5 group should be created/opened
    if (present(group)) then
      call hdf5_open_group(group)
    else
      temp_group = hdf5_fh
    endif

    ! Write the data
    call hdf5_write_integer_1Darray(temp_group, name, buffer, length)

    ! Check if HDF5 group should be closed
    if (present(group)) call hdf5_close_group()
#elif MPI
    call mpi_write_integer_1Darray(mpi_fh, buffer, length)
#else
    write(UNIT_OUTPUT) buffer(1:length)
#endif

  end subroutine write_integer_1Darray

!===============================================================================
! READ_INTEGER_1DARRAY reads integer 1-D array data
!===============================================================================

  subroutine read_integer_1Darray(buffer, name, group, length, option)

    integer,      intent(in)           :: length    ! length of array to read
    integer,      intent(inout)        :: buffer(:) ! read data to here
    character(*), intent(in)           :: name      ! name of data
    character(*), intent(in), optional :: group     ! HDF5 group name
    character(*), intent(in), optional :: option    ! read option

#ifdef HDF5
    ! Check if HDF5 group should be created/opened
    if (present(group)) then
      call hdf5_open_group(group)
    else
      temp_group = hdf5_fh
    endif
# ifdef MPI
    ! Check for option for reading default is independent
    if (present(option)) then
      if (option == 'collective') then
        call hdf5_parallel_read_integer_1Darray(temp_group, name, buffer, &
             length, H5FD_MPIO_COLLECTIVE_F)
      else 
        call hdf5_parallel_read_integer_1Darray(temp_group, name, buffer, &
             length, H5FD_MPIO_INDEPENDENT_F)
      end if
    else
      ! Standard read call
      call hdf5_read_integer_1Darray(temp_group, name, buffer, length)
    end if
# else
    ! Read the data serial
    call hdf5_read_integer_1Darray(temp_group, name, buffer, length)
# endif
    if (present(group)) call hdf5_close_group()
#elif MPI
    call mpi_read_integer_1Darray(mpi_fh, buffer, length)
#else
    read(UNIT_OUTPUT) buffer(1:length)
#endif

  end subroutine read_integer_1Darray

!===============================================================================
! WRITE_INTEGER_2DARRAY writes integer 2-D array data
!===============================================================================

  subroutine write_integer_2Darray(buffer, name, group, length)

    integer,      intent(in)           :: length(2) ! length of dimensions
    integer,      intent(in)           :: buffer(length(1),length(2)) ! data
    character(*), intent(in)           :: name ! name of data
    character(*), intent(in), optional :: group ! HDF5 group name

#ifdef HDF5
    ! Check if HDF5 group should be created/opened
    if (present(group)) then
      call hdf5_open_group(group)
    else
      temp_group = hdf5_fh
    endif

    ! Write the data
    call hdf5_write_integer_2Darray(temp_group, name, buffer, length)

    ! Check if HDF5 group should be closed
    if (present(group)) call hdf5_close_group()
#else
    message = 'Integer 2-D array writing not currently supported'
    call warning()
#endif

  end subroutine write_integer_2Darray

!===============================================================================
! WRITE_INTEGER_3DARRAY writes integer 3-D array data
!===============================================================================

  subroutine write_integer_3Darray(buffer, name, group, length)

    integer,      intent(in)           :: length(3) ! length of dimensions
    integer,      intent(in)           :: buffer(length(1),length(2),length(3)) 
    character(*), intent(in)           :: name ! name of data
    character(*), intent(in), optional :: group ! HDF5 group name

#ifdef HDF5
    ! Check if HDF5 group should be created/opened
    if (present(group)) then
      call hdf5_open_group(group)
    else
      temp_group = hdf5_fh
    endif

    ! Write the data
    call hdf5_write_integer_3Darray(temp_group, name, buffer, length)

    ! Check if HDF5 group should be closed
    if (present(group)) call hdf5_close_group()
#else
    message = 'Integer 3-D array writing not currently supported'
    call warning()
#endif

  end subroutine write_integer_3Darray

!===============================================================================
! WRITE_LONG writes long integer scalar data
!===============================================================================

  subroutine write_long(buffer, name, group)

    integer(8),   intent(in)           :: buffer ! data to write
    character(*), intent(in)           :: name   ! name of data
    character(*), intent(in), optional :: group  ! HDF5 group name

#ifdef HDF5
    ! Check if HDF5 group should be created/opened
    if (present(group)) then
      call hdf5_open_group(group)
    else
      temp_group = hdf5_fh
    endif

    ! Write the data
    call hdf5_write_long(temp_group, name, buffer, hdf5_integer8_t)

    ! Check if HDF5 group should be closed
    if (present(group)) call hdf5_close_group()
#elif MPI
    call mpi_write_long(mpi_fh, buffer)
#else
    write(UNIT_OUTPUT) buffer
#endif

  end subroutine write_long

!===============================================================================
! READ_LONG reads long integer scalar data
!===============================================================================

  subroutine read_long(buffer, name, group, option)

    integer(8),   intent(inout)        :: buffer ! read data to here
    character(*), intent(in)           :: name   ! name of data
    character(*), intent(in), optional :: group  ! HDF5 group name
    character(*), intent(in), optional :: option ! read option

#ifdef HDF5
    ! Check if HDF5 group should be created/opened
    if (present(group)) then
      call hdf5_open_group(group)
    else
      temp_group = hdf5_fh
    endif
# ifdef MPI
    ! Check for option for reading default is independent
    if (present(option)) then
      if (option == 'collective') then
        call hdf5_parallel_read_long(temp_group, name, buffer, &
             hdf5_integer8_t, H5FD_MPIO_COLLECTIVE_F)
      else 
        call hdf5_parallel_read_long(temp_group, name, buffer, &
             hdf5_integer8_t, H5FD_MPIO_INDEPENDENT_F)
      end if
    else
      ! Standard read call
      call hdf5_read_long(temp_group, name, buffer, hdf5_integer8_t)
    end if
# else
    ! Read the data serial
    call hdf5_read_long(temp_group, name, buffer, hdf5_integer8_t)
# endif
    ! Check if HDF5 group should be closed
    if (present(group)) call hdf5_close_group()
#elif MPI
    call mpi_read_long(mpi_fh, buffer)
#else
    read(UNIT_OUTPUT) buffer
#endif

  end subroutine read_long

!===============================================================================
! WRITE_STRING writes string data
!===============================================================================

  subroutine write_string(buffer, name, group)

    character(*), intent(in)           :: buffer ! data to write
    character(*), intent(in)           :: name   ! name of data
    character(*), intent(in), optional :: group  ! HDF5 group name

#ifndef HDF5
# ifdef MPI
    integer :: n ! length of string buffer to write
# endif
#endif

#ifdef HDF5
    ! Check if HDF5 group should be created/opened
    if (present(group)) then
      call hdf5_open_group(group)
    else
      temp_group = hdf5_fh
    endif

    ! Write the data
    call hdf5_write_string(temp_group, name, buffer, len(buffer))

    ! Check if HDf5 group should be closed
    if (present(group)) call hdf5_close_group()
#elif MPI
    ! Length of string buffer to write
    n = len(buffer)

    ! Write the data
    call mpi_write_string(mpi_fh, buffer, n)
#else
    write(UNIT_OUTPUT) buffer
#endif

  end subroutine write_string

!===============================================================================
! READ_STRING reads string data
!===============================================================================

  subroutine read_string(buffer, name, group, option)

    character(*), intent(inout)        :: buffer ! read data to here
    character(*), intent(in)           :: name   ! name of data
    character(*), intent(in), optional :: group  ! HDF5 group name
    character(*), intent(in), optional :: option ! read option

    integer :: n ! length of string to read to

    ! Length of string buffer to read
    n = len(buffer)

#ifdef HDF5
    ! Check if HDF5 group should be created/opened
    if (present(group)) then
      call hdf5_open_group(group)
    else
      temp_group = hdf5_fh
    endif
# ifdef MPI
    ! Check for option for reading default is independent
    if (present(option)) then
      if (option == 'collective') then
        call hdf5_parallel_read_string(temp_group, name, buffer, n, &
             H5FD_MPIO_COLLECTIVE_F)
      else 
        call hdf5_parallel_read_string(temp_group, name, buffer, n, &
             H5FD_MPIO_INDEPENDENT_F)
      end if
    else
      ! Standard read call
      call hdf5_read_string(temp_group, name, buffer)
    end if
# else
    ! Read the data serial
    call hdf5_read_string(temp_group, name, buffer)
# endif
    ! Check if HDF5 group should be closed
    if (present(group)) call hdf5_close_group()
#elif MPI

    ! Read the data
    call mpi_read_string(mpi_fh, buffer, n)
#else
    read(UNIT_OUTPUT) buffer
#endif

  end subroutine read_string

!===============================================================================
! WRITE_ATTRIBUTE_STRING
!===============================================================================

  subroutine write_attribute_string(var, attr_type, attr_str, group)

    character(*), intent(in)           :: var       ! variable name for attr
    character(*), intent(in)           :: attr_type ! attr identifier type
    character(*), intent(in)           :: attr_str  ! string for attr id type
    character(*), intent(in), optional :: group     ! HDF5 group name

#ifdef HDF5
    ! Check if HDF5 group should be created/opened
    if (present(group)) then
      call hdf5_open_group(group)
    else
      temp_group = hdf5_fh
    endif

    ! Write the attribute string
    call hdf5_write_attribute_string(temp_group, var, attr_type, attr_str)

    ! Check if HDF5 group should be closed
    if (present(group)) call hdf5_close_group()
#endif

  end subroutine write_attribute_string

!===============================================================================
! WRITE_TALLY_RESULT writes an OpenMC TallyResult type
!===============================================================================

  subroutine write_tally_result(buffer, name, group, n1, n2)

    character(*),      intent(in), optional :: group   ! HDF5 group name
    character(*),      intent(in)           :: name    ! name of data
    integer,           intent(in)           :: n1, n2  ! TallyResult dims
    type(TallyResult), intent(in), target   :: buffer(n1, n2) ! data to write

#ifndef HDF5
# ifndef MPI
    integer :: j,k ! iteration counters
# endif
#endif

#ifdef HDF5

    ! Open up sub-group if present
    if (present(group)) then
      call hdf5_open_group(group)
    else
      temp_group = hdf5_fh
    end if

    ! Set overall size of vector to write
    dims1(1) = n1*n2 

    ! Create up a dataspace for size
    call h5screate_simple_f(1, dims1, dspace, hdf5_err)

    ! Create the dataset
    call h5dcreate_f(temp_group, name, hdf5_tallyresult_t, dspace, dset, &
         hdf5_err)

    ! Set pointer to first value and write
    f_ptr = c_loc(buffer(1,1))
    call h5dwrite_f(dset, hdf5_tallyresult_t, f_ptr, hdf5_err)

    ! Close ids
    call h5dclose_f(dset, hdf5_err)
    call h5sclose_f(dspace, hdf5_err)
    if (present(group)) then
      call hdf5_close_group()
    end if

#elif MPI

    ! Write out tally buffer
    call MPI_FILE_WRITE(mpi_fh, buffer, n1*n2, MPI_TALLYRESULT, &
         MPI_STATUS_IGNORE, mpiio_err)

#else

    ! Write out tally buffer
    do k = 1, n2
      do j = 1, n1
        write(UNIT_OUTPUT) buffer(j,k) % sum
        write(UNIT_OUTPUT) buffer(j,k) % sum_sq
      end do
    end do

#endif 
   
  end subroutine write_tally_result

!===============================================================================
! READ_TALLY_RESULT reads OpenMC TallyResult data
!===============================================================================

  subroutine read_tally_result(buffer, name, group, n1, n2)

    character(*),      intent(in), optional  :: group  ! HDF5 group name
    character(*),      intent(in)            :: name   ! name of data
    integer,           intent(in)            :: n1, n2 ! TallyResult dims
    type(TallyResult), intent(inout), target :: buffer(n1, n2) ! read data here

#ifndef HDF5
# ifndef MPI
    integer :: j,k ! iteration counters
# endif
#endif

#ifdef HDF5

    ! Open up sub-group if present
    if (present(group)) then
      call hdf5_open_group(group)
    else
      temp_group = hdf5_fh
    end if

    ! Open the dataset
    call h5dopen_f(temp_group, name, dset, hdf5_err)

    ! Set pointer to first value and write
    f_ptr = c_loc(buffer(1,1))
    call h5dread_f(dset, hdf5_tallyresult_t, f_ptr, hdf5_err)

    ! Close ids
    call h5dclose_f(dset, hdf5_err)
    if (present(group)) call hdf5_close_group()

#elif MPI

    ! Write out tally buffer
    call MPI_FILE_READ(mpi_fh, buffer, n1*n2, MPI_TALLYRESULT, &
         MPI_STATUS_IGNORE, mpiio_err)

#else

    ! Write out tally buffer
    do k = 1, n2
      do j = 1, n1
        read(UNIT_OUTPUT) buffer(j,k) % sum
        read(UNIT_OUTPUT) buffer(j,k) % sum_sq
      end do
    end do

#endif 
   
  end subroutine read_tally_result


!===============================================================================
! WRITE_SOURCE_BANK writes OpenMC source_bank data
!===============================================================================

  subroutine write_source_bank()

#ifdef HDF5
    integer(8)               :: offset(1)        ! source data offset
#elif MPI
    integer(MPI_OFFSET_KIND) :: offset           ! offset of data
    integer                  :: size_offset_kind ! the data offset kind
    integer                  :: size_bank        ! size of bank to write
#endif

#ifdef HDF5
# ifdef MPI

    ! Set size of total dataspace for all procs and rank
    dims1(1) = n_particles
    hdf5_rank = 1

    ! Create that dataspace
    call h5screate_simple_f(hdf5_rank, dims1, dspace, hdf5_err)

    ! Create the dataset for that dataspace
    call h5dcreate_f(hdf5_fh, "source_bank", hdf5_bank_t, dspace, dset, hdf5_err)

    ! Close the dataspace
    call h5sclose_f(dspace, hdf5_err)

    ! Create another data space but for each proc individually
    dims1(1) = work
    call h5screate_simple_f(hdf5_rank, dims1, memspace, hdf5_err)

    ! Get the individual local proc dataspace
    call h5dget_space_f(dset, dspace, hdf5_err)

    ! Select hyperslab for this dataspace
    offset(1) = bank_first - 1_8
    call h5sselect_hyperslab_f(dspace, H5S_SELECT_SET_F, offset, dims1, hdf5_err)

    ! Set up the property list for parallel writing
    call h5pcreate_f(H5P_DATASET_XFER_F, plist, hdf5_err)
    call h5pset_dxpl_mpio_f(plist, H5FD_MPIO_COLLECTIVE_F, hdf5_err)

    ! Set up pointer to data
    f_ptr = c_loc(source_bank(1))

    ! Write data to file in parallel
    call h5dwrite_f(dset, hdf5_bank_t, f_ptr, hdf5_err, &
         file_space_id = dspace, mem_space_id = memspace, &
         xfer_prp = plist)

    ! Close all ids
    call h5sclose_f(dspace, hdf5_err)
    call h5sclose_f(memspace, hdf5_err)
    call h5dclose_f(dset, hdf5_err)
    call h5pclose_f(plist, hdf5_err)

# else

    ! Set size
    dims1(1) = work
    hdf5_rank = 1

    ! Create dataspace
    call h5screate_simple_f(hdf5_rank, dims1, dspace, hdf5_err)

    ! Create dataset
    call h5dcreate_f(hdf5_fh, "source_bank", hdf5_bank_t, &
         dspace, dset, hdf5_err)

    ! Set up pointer to data
    f_ptr = c_loc(source_bank(1))

    ! Write dataset to file
    call h5dwrite_f(dset, hdf5_bank_t, f_ptr, hdf5_err)

    ! Close all ids
    call h5dclose_f(dset, hdf5_err)
    call h5sclose_f(dspace, hdf5_err)

# endif 

#elif MPI

    ! Get current offset for master 
    if (master) call MPI_FILE_GET_POSITION(mpi_fh, offset, mpiio_err)

    ! Determine offset on master process and broadcast to all processors
    call MPI_SIZEOF(offset, size_offset_kind, mpi_err)
    select case (size_offset_kind)
    case (4)
      call MPI_BCAST(offset, 1, MPI_INTEGER, 0, MPI_COMM_WORLD, mpi_err)
    case (8)
      call MPI_BCAST(offset, 1, MPI_INTEGER8, 0, MPI_COMM_WORLD, mpi_err)
    end select

    ! Set the proper offset for source data on this processor
    call MPI_TYPE_SIZE(MPI_BANK, size_bank, mpi_err)
    offset = offset + size_bank*maxwork*rank

    ! Write all source sites
    call MPI_FILE_WRITE_AT(mpi_fh, offset, source_bank(1), work, MPI_BANK, &
         MPI_STATUS_IGNORE, mpiio_err)

#else

    ! Write out source sites
    write(UNIT_OUTPUT) source_bank

#endif

  end subroutine write_source_bank

!===============================================================================
! READ_SOURCE_BANK reads OpenMC source_bank data
!===============================================================================

  subroutine read_source_bank()

#ifdef HDF5
    integer(8)               :: offset(1)        ! offset of data
#elif MPI
    integer(MPI_OFFSET_KIND) :: offset           ! offset of data
    integer                  :: size_offset_kind ! the data offset kind
    integer                  :: size_bank        ! size of bank to read
#endif

#ifdef HDF5
# ifdef MPI

    ! Set size of total dataspace for all procs and rank
    dims1(1) = n_particles
    hdf5_rank = 1

    ! Open the dataset
    call h5dopen_f(hdf5_fh, "source_bank", dset, hdf5_err)

    ! Create another data space but for each proc individually
    dims1(1) = work
    call h5screate_simple_f(hdf5_rank, dims1, memspace, hdf5_err)

    ! Get the individual local proc dataspace
    call h5dget_space_f(dset, dspace, hdf5_err)

    ! Select hyperslab for this dataspace
    offset(1) = bank_first - 1_8
    call h5sselect_hyperslab_f(dspace, H5S_SELECT_SET_F, offset, dims1, hdf5_err)

    ! Set up the property list for parallel writing
    call h5pcreate_f(H5P_DATASET_XFER_F, plist, hdf5_err)
    call h5pset_dxpl_mpio_f(plist, H5FD_MPIO_COLLECTIVE_F, hdf5_err)

    ! Set up pointer to data
    f_ptr = c_loc(source_bank(1))

    ! Read data from file in parallel
    call h5dread_f(dset, hdf5_bank_t, f_ptr, hdf5_err, &
         file_space_id = dspace, mem_space_id = memspace, &
         xfer_prp = plist)

    ! Close all ids
    call h5sclose_f(dspace, hdf5_err)
    call h5sclose_f(memspace, hdf5_err)
    call h5dclose_f(dset, hdf5_err)
    call h5pclose_f(plist, hdf5_err)

# else

    ! Open dataset
    call h5dopen_f(hdf5_fh, "source_bank", dset, hdf5_err)

    ! Set up pointer to data
    f_ptr = c_loc(source_bank(1))

    ! Read dataset from file
    call h5dread_f(dset, hdf5_bank_t, f_ptr, hdf5_err)

    ! Close all ids
    call h5dclose_f(dset, hdf5_err)

# endif 

#elif MPI

    ! Get current offset for master 
    if (master) call MPI_FILE_GET_POSITION(mpi_fh, offset, mpiio_err)

    ! Determine offset on master process and broadcast to all processors
    call MPI_SIZEOF(offset, size_offset_kind, mpi_err)
    select case (size_offset_kind)
    case (4)
      call MPI_BCAST(offset, 1, MPI_INTEGER, 0, MPI_COMM_WORLD, mpi_err)
    case (8)
      call MPI_BCAST(offset, 1, MPI_INTEGER8, 0, MPI_COMM_WORLD, mpi_err)
    end select

    ! Set the proper offset for source data on this processor
    call MPI_TYPE_SIZE(MPI_BANK, size_bank, mpi_err)
    offset = offset + size_bank*maxwork*rank

    ! Write all source sites
    call MPI_FILE_READ_AT(mpi_fh, offset, source_bank(1), work, MPI_BANK, &
         MPI_STATUS_IGNORE, mpiio_err)

#else

    ! Write out source sites
    read(UNIT_OUTPUT) source_bank

#endif

  end subroutine read_source_bank

end module output_interface
