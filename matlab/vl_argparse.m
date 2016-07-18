function [opts, args] = vl_argparse(opts, args, varargin)
%VL_ARGPARSE Parse list of parameter-value pairs.
%   OPTS = VL_ARGPARSE(OPTS, ARGS) updates the structure OPTS based on
%   the specified parameter-value pairs ARGS={PAR1, VAL1, ... PARN,
%   VALN}. If a parameter PAR cannot be matched to any of the fields
%   in OPTS, the function generates an error.
%
%   Parameters that have a struct value in OPTS are processed
%   recursively, updating the individual subfields.  This behaviour
%   can be suppressed by using VL_ARGPARSE(OPTS, ARGS, 'nonrecursive'),
%   in which case the struct value is copied directly (hence deleting any
%   existing subfield existing in OPTS). A direct copy occurrs also if the
%   struct value in OPTS is a structure with no fields. The nonrecursive
%   mode is especially useful when a processing time is a concern.
%
%   One or more of the (PAR, VAL) pairs in the argument list can be
%   replaced by a structure; in this case, the fields of the structure
%   are used as paramater names and the field values as parameter
%   values. This behaviour, while orthogonal to structure-valued parameters,
%   is also disabled in the 'nonrecursive' mode.
%
%   [OPTS, ARGS] = VL_ARGPARSE(OPTS, ARGS) copies any parameter in
%   ARGS that does not match OPTS back to ARGS instead of producing an
%   error. Options specified as structures are passed back as a list
%   of (PAR, VAL) pairs.
%
%   Example::
%     The function can be used to parse a list of arguments
%     passed to a MATLAB functions:
%
%        function myFunction(x,y,z,varargin)
%        opts.parameterName = defaultValue ;
%        opts = vl_argparse(opts, varargin)
%
%     If only a subset of the options should be parsed, for example
%     because the other options are interpreted by a subroutine, then
%     use the form
%
%        [opts, varargin] = vl_argparse(opts, varargin)
%
%     that copies back to VARARGIN any unknown parameter.
%
%   See also: VL_HELP().

% Copyright (C) 2015-16 Andrea Vedaldi and Karel Lenc.
% Copyright (C) 2007-12 Andrea Vedaldi and Brian Fulkerson.
% All rights reserved.
%
% This file is part of the VLFeat library and is made available under
% the terms of the BSD license (see the COPYING file).

if ~isstruct(opts), error('OPTS must be a structure') ; end
if ~iscell(args), args = {args} ; end

recursive = true ;
if numel(varargin) == 1
  if strcmp(lower(varargin{1}), 'nonrecursive') ;
    recursive = false ;
  else
    error('Unknown option specified.') ;
  end
end
if numel(varargin) > 1
  error('There can be at most one option.') ;
end

optNames = fieldnames(opts)' ;

% convert ARGS into a structure
ai = 1 ;
keep = false(size(args)) ;
while ai <= numel(args)

  % Check whether the argument is a (param,value) pair or a structure.
  if recursive && isstruct(args{ai})
    params = fieldnames(args{ai})' ;
    values = struct2cell(args{ai})' ;
    if nargout == 1
      opts = vl_argparse(opts, vertcat(params,values)) ;
    else
      [opts, rest] = vl_argparse(opts, reshape(vertcat(params,values), 1, [])) ;
      args{ai} = cell2struct(rest(2:2:end), rest(1:2:end), 2) ;
      keep(ai) = true ;
    end
    ai = ai + 1 ;
    continue ;
  end

  if ~isstr(args{ai})
    error('Expected either a param-value pair or a structure.') ;
  end

  param = args{ai} ;
  value = args{ai+1} ;

  p = find(strcmpi(param, optNames)) ;
  if numel(p) ~= 1
    if nargout == 1
      error('Unknown parameter ''%s''', param) ;
    else
      keep([ai,ai+1]) = true ;
      ai = ai + 2 ;
      continue ;
    end
  end
  field = optNames{p} ;

  if ~recursive
    opts.(field) = value ;
  else
    if isstruct(opts.(field)) && numel(fieldnames(opts.(field))) > 0
      % The parameter has a  non-empty struct value in OPTS:
      % process recursively.
      if ~isstruct(value)
        error('Cannot assign a non-struct value to the struct parameter ''%s''.', ...
          field) ;
      end
      if nargout > 1
        [opts.(field), args{ai+1}] = vl_argparse(opts.(field), value) ;
      else
        opts.(field) = vl_argparse(opts.(field), value) ;
      end
    else
      % The parameter does not have a struct value in OPTS: copy as is.
      opts.(field) = value ;
    end
  end

  ai = ai + 2 ;
end

args = args(keep) ;